var TotalWatchFrames = 20; // watch this many times
var watchCount = 0;
var logCount = 0;
var logOffset = 0;

// the iframe will call this function
function logMessage(msg)
{
  var log = $("log");
  var p = document.createElement("p");
  p.innerHTML = decodeURI( msg );
  if( logCount++ % 2 ){ p.className = "alternate"; }
  log.appendChild( p );
  new Effect.ScrollTo( p );
}
function markOffset(pos)
{
  logOffset = pos;
}

Event.observe(window,"load",function(){
  watch("test.log");
});

function watch(file)
{
  var request = "/log?file=" + file + "&offset=" + logOffset;

  var onComplete = function(){
      if( TotalWatchFrames > watchCount++ ){
        setTimeout( watch.bind(window,file), 500 ); 
      } 
    };

//  if( Prototype.Browser.IE || !window.XMLHttpRequest ){
    var iframe = document.createElement("iframe");
    iframe.src = request;
    Event.observe( iframe, "load", onComplete );
    $("watch").appendChild(iframe);
/*  }
  else {
    new Ajax.Request( request, {
      onLoading: function(req){
        eval( req.responseText );
      },
      onComplete: onComplete
    } );
  }*/
}
