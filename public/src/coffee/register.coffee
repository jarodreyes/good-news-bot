$(document).ready ->
  addVerify = (e) ->
    console.log e
    $('.regButton').fadeOut(300)
    $('.verifyCode').fadeIn(300)

  showErrors = (e) ->
    console.log "Error: #{e}"
    $('.register-error').fadeIn(300).text(e)


  $('#signup').submit (e) ->
    $('.register-error').fadeOut(300)
    e.preventDefault()
    $.ajax
      type: "POST",
      url: '/register',
      data: $('#signup').serialize()
      error: (e) ->
        showErrors(e.response)
      success: (data) ->
        addVerify()
    return false

  $('.codeSubmit').click (e) ->
    e.preventDefault()
    pn = $('input[name="phone_number"]').val()
    if pn.length <= 10
      pn = "+1" + pn
    data =
      'phone_number': pn
      'code': $('input[name="code"]').val()
    $.ajax
      type: "POST",
      url: '/verify',
      data: data,
      success: =>
        $('.status .alert-box').hide()
        $('.success').fadeIn(300)
        setTimeout =>
          document.location = '/success'
        , 500
      ,
      error: =>
        $('.status .alert-box').hide()
        $('.error').fadeIn(300)
    return false