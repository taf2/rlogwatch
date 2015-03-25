Similar to "tail -f", but viewable in a browser.  It provides some basic server side code to tail logs as well as some basic client side code to view the log as it streams to the client browser.

After running..

./bin/log\_watch.rb start


browse to: http://localhost:4000/?file=test.log

where file= a file on the file system to tail
