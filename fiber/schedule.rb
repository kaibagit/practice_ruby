require 'set'
require 'thread'
require 'fiber'
require 'logger'

logger = Logger.new(STDOUT)
logger.formatter = proc { |severity, datetime, progname, msg|
	"#{datetime} #{severity}  [#{Thread.current}]: #{msg}\n"
}

class BlockingCallback

	attr_accessor :fiber_id, :exec_result

	def initialize(fiber_id,exec_result)
		@fiber_id = fiber_id
		@exec_result = exec_result
	end

end

class BlockingThreadPool

	def initialize(scheduler)
		@scheduler = scheduler
	end

	def submit(fiber_id,&task)
		Thread.new {
			result = task.call
			callback_data = BlockingCallback.new(fiber_id,result)
			@scheduler.exec_blocking_return callback_data
		}
	end
end

class Scheduler
	
	def initialize()
		@blocked_fibers =  Hash.new
		@runnable_fibers = Queue.new
		@callback_queue = Queue.new
		@io_thread_pool = BlockingThreadPool.new(self)
	end	

	def submit(&task)
		new_fiber = SchedulableFiber.new &task
		submit_fiber new_fiber
	end

	def submit_fiber(new_fiber)
		new_fiber.scheduler = self
		@runnable_fibers << new_fiber
	end

	def start_looping
		while(true)
			complated_size = @callback_queue.length
			complated_size.times do
				data = @callback_queue.pop
				fiber = @blocked_fibers.delete data.fiber_id
				fiber.resume_value = data.exec_result
				@runnable_fibers << fiber
			end

			fiber_size = @runnable_fibers.length
			if fiber_size == 0 
				sleep 1
				next
			end
			fiber = @runnable_fibers.pop
			fiber.resume
		end
	end

	def begin_block(fiber,&block_task)
		@blocked_fibers.store(fiber.object_id,fiber)
		@io_thread_pool.submit(fiber.object_id,&block_task)
	end

	def exec_blocking_return(callback_data)
		@callback_queue << callback_data
	end
end
class SchedulableFiber < Fiber

	attr_accessor :scheduler,:resume_value

	def await(&block)
		@scheduler.begin_block(Fiber.current,&block)
		Fiber.yield
		@resume_value
	end
end

scheduler = Scheduler.new
fiber = SchedulableFiber.new do
	logger.info "【1】get data from redis"
	value = Fiber.current.await {sleep 1;nil}
	logger.info "【1】redis value = #{value}"
	if value.nil?
		logger.info "【1】get data from db"
		value = Fiber.current.await{sleep 3;5*5}
	end
	logger.info "【1】result = #{value}"
end
fiber2 = SchedulableFiber.new do
	logger.info "【2】get data from db"
	value = Fiber.current.await {sleep 3;1+1}
	logger.info "【2】db value = #{value}"
	logger.info "【2】put value to redis"
	Fiber.current.await{sleep 1;nil}
	logger.info "【2】result = #{value}"
	fiber3 = SchedulableFiber.new do
		logger.info "【3】hello!"
	end
	scheduler.submit_fiber fiber3
end
scheduler.submit_fiber fiber
scheduler.submit_fiber fiber2
scheduler.submit do
	logger.info "【4】get data from redis"
	value = Fiber.current.await {sleep 1;nil}
	logger.info "【4】redis value = #{value}"
	if value.nil?
		logger.info "【4】get data from db"
		value = Fiber.current.await{sleep 3;2*2}
	end
	logger.info "【4】result = #{value}"
end
scheduler.start_looping