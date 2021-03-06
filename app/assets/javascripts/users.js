function taxonomy_added(taxonomies, type)
{
  var selected = [["",""]];
  selected.push.apply(selected, get_select_values(taxonomies));
  var defaults = document.getElementById("user_default_" + type + "_id");
  defaults.length = 0; // Clear default taxonomies select

  for(var i = 0; i < selected.length; i++) {
    var opt = selected[i];
    var el = document.createElement("option");
    el.value       = opt[0];
    el.textContent = opt[1];
    defaults.appendChild(el);
  }
}

function get_select_values(select) {
  var result = [];
  var options = select && select.options;
  var opt;

  for (var i=0, iLen=options.length; i<iLen; i++) {
    opt = options[i];

    if (opt.selected) {
      result.push([opt.value, opt.text]);
    }
  }

  return result;
}

function test_mail(item, id, url) {
  $(item).addClass("disabled");
  $('#test_indicator').show();
  var email = $("#user_mail").val();
  var param = {user_email: email};
  $.ajax({
    url: url,
    type: 'put',
    data: param,
    success: function(result, textstatus, xhr) {
      notify("<p>" + result.message + "</p>", 'success');
    },
    error: function (xhr) {
      var error = $.parseJSON(xhr.responseText).message;
      notify("<p>" + error + "</p>", 'error');
    },
    complete: function (result) {
      $('#test_indicator').hide();
      $(item).removeClass("disabled");
    }
  })
}
