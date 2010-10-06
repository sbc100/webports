var encryptedClassName = "x-aesEncrypted";

if (document.getElementsByClassName(encryptedClassName).length) {
  chrome.extension.sendRequest({type:"showIcon"}); 
}

// Decrypts text of the |element|. Decryption is implemented in NaCl
// module embedded in the background page. Calling |decryptElement|
// creates a closure, with |element| bound to the callback function.
function decryptElement(pwd, element) {
  var msg = {type:"decrypt", pwd:pwd, cipherText:element.innerText};
  chrome.extension.sendRequest(msg, function(response) {
    if (response.type == "plainText") {
      element.innerHTML = response.plainText;
      chrome.extension.sendRequest({type:"hideIcon"}); 
    }
  });
}

// Decrypts all encrypted text in the page.
function decryptPage(pwd) {
  var encryptedElements = document.getElementsByClassName(encryptedClassName);
  for (var i = 0; i < encryptedElements.length; i++) {
    decryptElement(pwd, encryptedElements[i]);
  }
}

// Handles messages from background page.
chrome.extension.onRequest.addListener(
  function(request, sender, sendResponse) {
    if (request.type == "decryptPage") 
      decryptPage(request.pwd);
    sendResponse({});
  });

