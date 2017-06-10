require 'set'

set1 = Set.new ["foo", "bar", "baz", "foo"]
p set1			#=> #<Set: {"baz", "foo", "bar"}>
p set1.include?("bar")	#=> true
set1.add("heh")
set1.delete("foo")
p set1			#=> #<Set: {"heh", "baz", "bar"}>