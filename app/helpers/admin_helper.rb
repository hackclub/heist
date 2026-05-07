# frozen_string_literal: true

module AdminHelper
  def admin_tab_link(label, path)
    classes = [ "heist-admin__tab" ]
    classes << "heist-admin__tab--active" if request.path.start_with?(path) && path != "/"
    link_to label, path, class: classes.join(" ")
  end
end
