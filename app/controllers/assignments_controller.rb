require 'net/http'
require 'json'
require 'haversine'

class AssignmentsController < ApplicationController

  def index
    drones = populate_drones
    packages = populate_packages
    drones.sort_by! { |drone| (drone['time_to_return']) }
    packages.sort_by! { |package| (package['secs_until_deadline'] - package['time_to_destination']) }
    render json: assign_jobs(packages, drones)
  end

  private
  def populate_drones
    drones = JSON.parse(Net::HTTP.get(URI('https://codetest.kube.getswift.co/drones')))
    drones.each do |drone|
      distance_to_return = 0
      drone_location = [drone['location']['latitude'], drone['location']['longitude']]
      if drone['packages'].empty?
        distance_to_return += distance_from_hub(drone_location)
      else
        drone_destination = [drone['packages'][0]['destination']['latitude'],
           drone['packages'][0]['destination']['longitude']]
        distance_to_return += distance_from_hub(drone_destination)
        distance_to_return += distance_between_points(drone_location, drone_destination)
      end
      drone['time_to_return'] = (3600 * distance_to_return) / 50
    end
    drones
  end

  def populate_packages
    packages = JSON.parse(Net::HTTP.get(URI('https://codetest.kube.getswift.co/packages')))
    packages.each do |package|
      package['secs_until_deadline'] = package['deadline'] - Time.now.to_i
      distance_to_destination = distance_from_hub(
        [package['destination']['latitude'], package['destination']['longitude']])
      package['time_to_destination'] = (3600 * distance_to_destination) / 50
    end
    packages
  end

  def assign_jobs(packages, drones)
    assigned_jobs = { 'assignments' => [], 'unassignedPackageIds' => [] }
    until packages.empty?
      if drones.empty? || packages.first['time_to_destination'] + drones.first['time_to_return'] > packages.first['secs_until_deadline']
        assigned_jobs['unassignedPackageIds'].push(packages.first['packageId'])
      else
        assigned_jobs['assignments'].push({ droneId: drones.first['droneId'], packageId: packages.first['packageId']})
        drones.shift
      end
      packages.shift
    end
    assigned_jobs
  end

  def distance_from_hub(start_point)
    Haversine.distance([-37.816664, 144.963848], start_point).to_km
  end

  def distance_between_points(start_point, end_point)
    Haversine.distance(start_point, end_point).to_km
  end

end
