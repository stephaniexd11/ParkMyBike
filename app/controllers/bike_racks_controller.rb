require 'rubygems'
require 'open-uri'
require 'csv'

class BikeRacksController < ApplicationController

  BIKE_RACK_URI = 'ftp://webftp.vancouver.ca/opendata/bike_rack/BikeRackData.csv'

  def index
    @bike_racks = BikeRack.search(params[:search])
  end

  def internal
    @bike_racks = BikeRack.search(params[:search])
  end

  def full_update
    begin
      racks_data = open BIKE_RACK_URI
      update_bike_racks racks_data
    rescue StandardError => e
      handle_full_update_error e
    end
    redirect_to internal_path
  end

  private

  def update_bike_racks (racks_data)
    counter = {valid: 0, invalid: 0}
    CSV.foreach(open(racks_data), headers: true) do |rack_data|
      result = store_one_bike_rack(rack_data) ? :valid : :invalid
      counter[result] += 1
    end
    handle_finished_parsing counter
  end

  def store_one_bike_rack (data)
    @bike_rack = BikeRack.new(
      street_number: data['St Number'].strip,
      street_name: data['St Name'].strip,
      street_side: data['Street Side'].strip,
      number_of_racks: data['# of racks'])

    handle_validation_error(@bike_rack) unless @bike_rack.valid?
    @bike_rack.save
  end

  def handle_full_update_error (e)
    flash[:alert] = "Problem opening bike rack URL: #{BIKE_RACK_URI}. " +
        'Are things going okay over there?'
    logger.error "Error fetching data: #{e}"
  end

  def handle_validation_error (bike_rack)
    logger.warn 'Model validation error: ' +
                "#{bike_rack.street_number} #{@bike_rack.street_name}: " +
                bike_rack.errors.full_messages.first
  end

  def handle_finished_parsing (counter)
    if counter[:invalid].zero?
      flash[:notice] = "All #{counter[:valid]} bike rack(s) parsed successfully!"
    else
      flash[:info] = "#{counter[:valid]} bike rack(s) parsed successfully, and " +
          "#{counter[:invalid]} bike rack(s) were not parsed. " +
          'See server log for more details.'
    end
    logger.info "#{counter[:valid]} bike rack(s) parsed successfully."
    logger.info "#{counter[:invalid]} model validation error(s) found."
  end

end
