// Generated by CoffeeScript 1.10.0
(function() {
  $(document).ready(function() {
    var addVerify, showErrors;
    addVerify = function(e) {
      console.log(e);
      $('.regButton').fadeOut(300);
      return $('.verifyCode').fadeIn(300);
    };
    showErrors = function(e) {
      console.log("Error: " + e);
      return $('.register-error').fadeIn(300).text(e);
    };
    $('#signup').submit(function(e) {
      $('.register-error').fadeOut(300);
      e.preventDefault();
      $.ajax({
        type: "POST",
        url: '/register',
        data: $('#signup').serialize(),
        error: function(e) {
          return showErrors(e.response);
        },
        success: function(data) {
          return addVerify();
        }
      });
      return false;
    });
    return $('.codeSubmit').click(function(e) {
      var data, pn;
      e.preventDefault();
      pn = $('input[name="phone_number"]').val();
      if (pn.length <= 10) {
        pn = "+1" + pn;
      }
      data = {
        'phone_number': pn,
        'code': $('input[name="code"]').val()
      };
      $.ajax({
        type: "POST",
        url: '/verify',
        data: data,
        success: (function(_this) {
          return function() {
            $('.status .alert-box').hide();
            $('.success').fadeIn(300);
            return setTimeout(function() {
              return document.location = '/success';
            }, 500);
          };
        })(this),
        error: (function(_this) {
          return function() {
            $('.status .alert-box').hide();
            return $('.error').fadeIn(300);
          };
        })(this)
      });
      return false;
    });
  });

}).call(this);
