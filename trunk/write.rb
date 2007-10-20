

message = "hello there world"

1000.times do |i|
  `echo '#{31+ i} => #{message}' | cat >> test.log`
  puts i
#  sleep 1
end
