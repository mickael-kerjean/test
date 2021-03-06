class ApplicationController < ActionController::Base

  include MultiTenancy

  rescue_from DeviseLdapAuthenticatable::LdapException do |exception|
    render text: exception, status: 500
  end
  protect_from_forgery with: :null_session

  before_action :load_tenant
  before_action :authenticate_user!
  before_action :set_locale
  before_action :load_labels, if: :user_signed_in?
  before_action :show_joyride, if: :user_signed_in?, unless: :devise_controller?

  check_authorization unless: :devise_controller?

  rescue_from CanCan::AccessDenied do |exception|
    if Rails.env == :production
      redirect_to root_url, alert: exception.message
    else
      # for tests and development, we want unauthorized status codes
      render plain: exception, status: :unauthorized
    end
  end

  def permitted_params
    params.permit(:q, :status, :label_id)
  end

  helper_method :permitted_params

  protected

  def show_joyride
    @show_joyride = false
    if current_user.agent? && current_user.sign_in_count == 1 && !session[:seen_joyride]
      session[:seen_joyride] = true
      @show_joyride = true
    end
  end

  def load_labels
    @labels = Label.viewable_by(current_user).ordered
  end

  def set_locale
    @time_zones = ActiveSupport::TimeZone.all.map(&:name).sort
    @locales = []

    Dir.open("#{Rails.root}/config/locales").each do |file|
      unless ['.', '..'].include?(file) || file[0] == '.'
        code = file[0...-4] # strip of .yml
        @locales << [I18n.translate(:language_name, locale: code), code]
      end
    end

    if user_signed_in? && !current_user.locale.blank?
      I18n.locale = current_user.locale
    else
      locale = http_accept_language.compatible_language_from(@locales)

      if Tenant.current_tenant.ignore_user_agent_locale? || locale.blank?
        I18n.locale = Tenant.current_tenant.default_locale
      else
        I18n.locale = locale
      end
    end

    if I18n.locale == :fa
      @rtl = true
    else
      @rtl = false
    end
  end
end
