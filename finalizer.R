e = new.env()

reg.finalizer(e, function(e) {
  message('Bye!')
}, onexit = TRUE)
