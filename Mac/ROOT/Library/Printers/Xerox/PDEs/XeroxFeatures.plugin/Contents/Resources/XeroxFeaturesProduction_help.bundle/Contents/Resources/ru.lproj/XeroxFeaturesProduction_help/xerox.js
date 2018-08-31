// Functions for TOC

function exp(id) {
  var myElt=document.getElementById('p'+id);

  if (myElt) {
    // check current display state
    if (myElt.src.slice(myElt.src.lastIndexOf('/')+1) == 'minus.gif') {
      collapse(id);
    } else{
      expand(id);
    }
  }
}

function expand(id) {
  var myDoc= top.toc.document;
  var myElt=myDoc.getElementById('s'+id);

  if (myElt) {
    with(myElt) {
      className='x';
      style.display=''; 
    }
    myDoc.getElementById('p'+id).src='minus.gif';
    myDoc.getElementById('b'+id).src='obook.gif';
  }
}

function collapse(id) {
  var myElt=document.getElementById('s'+id);

  if (myElt) {
    with(myElt) {
      className='x';
      style.display='none'; 
    }
    document.getElementById('p'+id).src='plus.gif';
    document.getElementById('b'+id).src='cbook.gif';
  }
}

function highlight(id) {
  var myElt=top.toc.document.getElementById('a'+id);

  if (myElt) {
    myElt.hideFocus=true;
    //myElt.focus();
    myElt.setActive();
    top.toc.scrollTo(myElt.offsetLeft-49, myElt.offsetTop-(top.toc.document.body.clientHeight/3));
  }
}

function loadTOC() {
  // check current page displayed in TOC window.  If not toc.htm, load it.
  if (!isTOCLoaded()) {
    top.toc.location.href='toc.html';
  }
}

function isTOCLoaded() {
  // return true, if toc.htm is loaded in TOC window.
  if (top.toc) {
    var myPath=top.toc.location.pathname;
    var myFile=myPath.substr(myPath.length-8);

    if (myFile == 'toc.html') {
      return true;
    } else {
      return false; 
    }
  } else {
    return false;
  }
}

function loadTopic(){
  // Function to load the topic specified in the Query, and its associated toc
  var strLocation="?"+location+"?none?none";
  var locarray = strLocation.split("?");
  var strTocURL=""+locarray[2];
  var strBodyURL=""+locarray[3];

  if (strTocURL != "none") {
    window.toc.location=strTocURL
  }
  if (strBodyURL != "none") {
    window.content.location=strBodyURL
  }
}

function getLocationHash(){
  var hash=unescape(self.document.location.hash.substring(1));
  hash=hash.split("#");
  if (hash[0] != "") {
    if (hash[1] != undefined) {
//      alert(hash[0] + '.htm#' + hash[1])
      window.content.location=hash[0] + '.htm#' + hash[1]
    }
    else {
//      alert(hash[0] + '.htm')
      window.content.location=hash[0] + '.html'
    }
  }
}