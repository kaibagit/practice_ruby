require 'mongo'

client = Mongo::Client.new('mongodb://127.0.0.1:27017/test')
db = client.database
db.collections # returns a list of collection objects
db.collection_names # returns a list of collection names

collection = client[:users]
doc = { name: 'Steve', hobbies: [ 'hiking', 'tennis', 'fly fishing' ] }
result = collection.insert_one(doc)
puts result.n # returns 1, because one document was inserted