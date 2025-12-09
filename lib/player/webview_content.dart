const String playerHtmlContent = '''
<!doctype html><html>
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<style>
  html, body { height: 100%; margin: 0; background: #000; }
  #player { position: fixed; inset: 0; width: 100vw; height: 100vh; }
</style>
</head>
<body>
<div id="player"></div>
<script>
try{ if(window.flutter_inappwebview && window.flutter_inappwebview.callHandler){ window.flutter_inappwebview.callHandler('yt_log','boot: start href='+location.href); } }catch(_){ }
window.addEventListener('error', function(e){ try{ window.flutter_inappwebview.callHandler('yt_log','window.error: '+(e && e.message ? e.message : 'unknown')); }catch(_){ } });
var __ytInjectTries = 0;
function injectYT(){
  try{
    if (typeof YT==='undefined' || typeof YT.Player==='undefined'){
      __ytInjectTries++;
      var s=document.createElement('script');
      s.src='https://www.youtube.com/iframe_api';
      s.onerror=function(){ try{ window.flutter_inappwebview.callHandler('yt_log','iframe_api load error (try '+__ytInjectTries+')'); }catch(_){ } };
      s.onload=function(){ try{ window.flutter_inappwebview.callHandler('yt_log','iframe_api loaded (try '+__ytInjectTries+')'); }catch(_){ } };
      document.head.appendChild(s);
    }
  }catch(e){ try{ window.flutter_inappwebview.callHandler('yt_log','injectYT exception: '+e); }catch(_){ } }
}
injectYT();
var __probeCount=0;
var __probeTimer=setInterval(function(){
  __probeCount++;
  try{
    var ytt=typeof YT, plt=typeof player;
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler){ window.flutter_inappwebview.callHandler('yt_log','probe@html#'+__probeCount+': YT='+ytt+' player='+plt); }
  }catch(_){ }
  if (__probeCount<=5){ injectYT(); }
  if (__probeCount>=15){ clearInterval(__probeTimer); }
}, 1000);
</script>
<script>
var player, fallback=[0.5,1,1.25,1.5,2];
function onYouTubeIframeAPIReady(){
  try{ window.flutter_inappwebview.callHandler('yt_log','onYouTubeIframeAPIReady'); }catch(_){ }
  player=new YT.Player('player',{
    height: '100%', width: '100%', videoId:'',
    playerVars:{controls:1, rel:0, enablejsapi:1},
    host:'https://www.youtube.com',
    events:{
      onReady:()=>{ try{ if(window.__pendingId){ try{ window.flutter_inappwebview.callHandler('yt_log', 'onReady consume pendingId='+window.__pendingId); }catch(_){}; player.cueVideoById(window.__pendingId); } }catch(e){}; window.flutter_inappwebview.callHandler('yt_ready'); reportRate(); },
      onStateChange:(e)=>{ try{ window.flutter_inappwebview.callHandler('yt_state', e.data); reportRate(); }catch(_){} },
      onError:(e)=>{ try{ window.flutter_inappwebview.callHandler('yt_log', 'onError '+JSON.stringify(e)); window.flutter_inappwebview.callHandler('yt_error', e.data); }catch(_){} }
    }
  });
  window.pauseVideo = function(){
    try{
      if(player && typeof player.pauseVideo==='function'){ player.pauseVideo(); }
    }catch(e){ try{ window.flutter_inappwebview.callHandler('yt_log','pauseVideo error '+e); }catch(_){ } }
  }
  window.playVideo = function(){
    try{
      if(player && typeof player.playVideo==='function'){ player.playVideo(); }
    }catch(e){ try{ window.flutter_inappwebview.callHandler('yt_log','playVideo error '+e); }catch(_){ } }
  }
}
function nearestAllowed(r){
  var ar = (player && player.getAvailablePlaybackRates)?player.getAvailablePlaybackRates():fallback;
  var under = ar.filter(x=>x<=r);
  if (under.length===0) return 1.0;
  under.sort((a,b)=>Math.abs(r-a)-Math.abs(r-b));
  return under[0];
}
function setRate(r){ if(player){ player.setPlaybackRate(nearestAllowed(r)); reportRate(); } }
function pauseVideo(){ if(player){ player.pauseVideo(); } }
function cueVideoByIdX(id){
  try{
    if(player && typeof player.cueVideoById === 'function'){
      player.cueVideoById(id);
    } else {
      try{ window.flutter_inappwebview.callHandler('yt_log', 'queue pendingId='+id+' (player not ready)'); }catch(_){};
      window.__pendingId = id;
    }
  }catch(e){ window.__pendingId = id; }
}
function setPendingId(id){ window.__pendingId = id; }
function reportRate(){ if(player){ var pr = player.getPlaybackRate?player.getPlaybackRate():null; if(pr!=null){ window.flutter_inappwebview.callHandler('yt_rate', pr); } } }
setInterval(()=>{ try{ reportRate(); }catch(e){} }, 1000);
setInterval(()=>{ try{ if(window.__pendingId && player && typeof player.cueVideoById==='function'){ try{ window.flutter_inappwebview.callHandler('yt_log', 'consume pendingId='+window.__pendingId); }catch(_){}; player.cueVideoById(window.__pendingId); window.__pendingId=null; } }catch(e){} }, 500);
</script></body></html>
''';
