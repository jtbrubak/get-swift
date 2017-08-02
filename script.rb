require 'net/http'
require 'json'
require 'haversine'

def index
  drones = populate_drones
  packages = populate_packages
  drones.sort_by! { |drone| (drone['time_to_return']) }
  render json: assign_jobs(packages, drones)
  packages.sort_by! { |package| (package['secs_until_deadline'] - package['time_to_destination']) }
end

private
def populate_drones
  drones = []
  JSON.parse(Net::HTTP.get(URI('https://codetest.kube.getswift.co/drones'))).each do |drone|
    distance_to_return = 0
    drone_location = [drone['location']['latitude'], drone['location']['longitude']]
    drone_destination = drone['packages'].empty? ? nil :
      [drone['packages'][0]['destination']['latitude'],
       drone['packages'][0]['destination']['longitude']]
    if drone_destination.nil?
      distance_to_return += distance_from_hub(drone_location)
    else
      distance_to_return += (distance_from_hub(drone_destination)
        + distance_between_points(drone_location, drone_destination)
    end
    drone['time_to_return'] = (3600 * distance_to_return) / 20
    drones.push(drone)
  end
  drones
end

def populate_packages
  packages = []
  JSON.parse(Net::HTTP.get(URI('https://codetest.kube.getswift.co/packages'))).each do |package|
    package['secs_until_deadline'] = package['deadline'] - Time.now.to_i
    distance_to_destination = distance_from_hub(
      [package['destination']['latitude'], package['destination']['longitude']])
    package['time_to_destination'] = (3600 * distance_to_destination) / 20
    packages.push(package)
  end
  packages
end

def assign_jobs(packages, drones)
  assigned jobs = { 'assignments' => [], 'unassignedPackageIds' => [] }
  until packages.empty?
    if packages.first['time_to_destination'] + drones.first['time_to_return'] > packages.first['secs_until_deadline']
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
