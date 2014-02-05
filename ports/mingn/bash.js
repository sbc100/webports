NaClTerm.prefix = 'bash'
NaClTerm.nmf = 'bash.nmf'
NaClTerm.argv = ['--init-file', '/etc/bashrc']

// We cannot start bash until the storage request is approved.
NaClTerm.real_init = NaClTerm.init
NaClTerm.init = function() {
  // Request 1GB storage for mingn.
  navigator.webkitPersistentStorage.requestQuota(
      1000 * 1000 * 1000,
      NaClTerm.real_init,
      function() {});
}
