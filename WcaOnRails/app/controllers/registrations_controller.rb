class RegistrationsController < ApplicationController
  before_action :authenticate_user!, except: [:new, :create]

  before_action :can_manage_competition_only, only: [:index, :update_all, :update]
  private def can_manage_competition
    if params[:competition_id]
      competition = Competition.find(params[:competition_id])
    else
      registration = Registration.find(params[:id])
      competition = registration.competition
    end

    current_user.can_manage_competition?(competition)
  end
  private def can_manage_competition_only
    if !can_manage_competition
      flash[:danger] = "You are not allowed to manage this competition"
      redirect_to root_url
    end
  end

  def index
    @competition_registration_view = true
    @competition = Competition.find(params[:competition_id])
    respond_to do |format|
      format.html
      format.csv do
        headers['Content-Disposition'] = "attachment; filename=\"#{@competition.id}-registration.csv\""
        headers['Content-Type'] ||= 'text/csv; charset=UTF-8'
      end
    end
  end

  def edit
    @registration = Registration.find(params[:id])
    @competition = @registration.competition
  end

  def update_all
    @competition_registration_view = true
    @competition = Competition.find(params[:competition_id])
    ids = []
    registration_ids = params.select { |k| k.start_with?("registration-") }.map { |k, v| k.split('-')[1] }
    registrations = registration_ids.map do |registration_id|
      @competition.registrations.find_by_id!(registration_id)
    end
    case params[:registrations_action]
    when "accept-selected"
      registrations.each { |registration| registration.update_attribute(:status, "a") }
      flash[:success] = "#{"Registration".pluralize(registrations.length)} accepted!"
    when "reject-selected"
      registrations.each { |registration| registration.update_attribute(:status, "p") }
      flash[:warning] = "#{"Registration".pluralize(registrations.length)} moved to waiting list"
    when "delete-selected"
      registrations.each { |registration| registration.delete }
      flash[:warning] = "#{"Registration".pluralize(registrations.length)} deleted"
    else
      throw "Unrecognized action #{params[:registrations_action]}"
    end
    redirect_to competition_registrations_path(@competition)
  end

  def update
    @registration = Registration.find(params[:id])
    was_accepted = @registration.accepted?
    if @registration.update_attributes(registration_params)
      if !was_accepted && @registration.accepted?
        mailer = RegistrationsMailer.accepted_registration(@registration)
        mailer.deliver_now
        flash[:success] = "Accepted registration and emailed #{mailer.to.join(" ")}"
      else
        flash[:success] = "Updated registration"
      end
      redirect_to edit_registration_path(@registration)
    else
      flash[:danger] = "Could not update registration"
      render :edit
    end
  end

  def register
    competition = Competition.find(params[:competition_id])
    @registration = nil
    if current_user
      @registration = competition.registrations.where(user_id: current_user.id).first
    end
    if !@registration
      @registration = competition.registrations.build(user_id: current_user.id)
    end
  end

  def create
    competition = Competition.find(params[:competition_id])
    @registration = competition.registrations.build(registration_params.merge(user_id: current_user.id))
    if @registration.save
      flash[:success] = "Successfully registered!"
      RegistrationsMailer.notify_organizers_of_new_registration(@registration).deliver_now
      RegistrationsMailer.notify_registrant_of_new_registration(@registration).deliver_now
      redirect_to competition_register_path
    else
      render :register
    end
  end

  private def registration_params
    permitted_params = [
      :personId,
      :email,
      :name,
      :countryId,
      :birthday,
      :guests,
      :comments,
      event_ids: Event.all.map(&:id),
    ]
    if can_manage_competition
      permitted_params << :status
    end
    registration_params = params.require(:registration).permit(*permitted_params)

    if registration_params.has_key?(:event_ids)
      registration_params[:eventIds] = registration_params[:event_ids].select { |k, v| v == "1" }.keys.join " "
      registration_params.delete(:event_ids)
    end
    registration_params
  end
end
