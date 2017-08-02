require 'net/http'
require 'json'
require 'haversine'

hub_location = [-37.816664, 144.963848]
drones = []
packages = []
assigned_jobs = { 'assignments' => [], 'unassignedPackageIds' => [] }

JSON.parse(Net::HTTP.get(URI('https://codetest.kube.getswift.co/drones'))).each do |drone|
  distance_to_return = 0
  if drone['packages'].empty?
    distance_to_return += Haversine.distance(hub_location,
     [drone['location']['latitude'], drone['location']['longitude']]).to_km
  else
    distance_to_return += Haversine.distance([drone['location']['latitude'], drone['location']['longitude']],
     [drone['packages'][0]['destination']['latitude'], drone['packages'][0]['destination']['longitude']]).to_km
    distance_to_return += Haversine.distance(hub_location,
     [drone['packages'][0]['destination']['latitude'], drone['packages'][0]['destination']['longitude']]).to_km
  end
  drone['time_to_return'] = (3600 * distance_to_return) / 20
  drones.push(drone)
end

drones.sort_by! { |drone| (drone['time_to_return']) }

JSON.parse(Net::HTTP.get(URI('https://codetest.kube.getswift.co/packages'))).each do |package|
  package['secs_until_deadline'] = package['deadline'] - Time.now.to_i
  distance_to_destination = Haversine.distance(hub_location,
    [package['destination']['latitude'], package['destination']['longitude']]).to_km
  package['time_to_destination'] = (3600 * distance_to_destination) / 20
  if package['time_to_destination'] > package['secs_until_deadline']
    assigned_jobs['unassignedPackageIds'].push(package['packageId'])
  else
    packages.push(package)
  end
end

packages.sort_by! { |package| (package['secs_until_deadline'] - package['time_to_destination']) }
puts drones
puts packages

until packages.empty?
  if packages.first['time_to_destination'] + drones.first['time_to_return'] > packages.first['secs_until_deadline']
    assigned_jobs['unassignedPackageIds'].push(packages.first['packageId'])
  else
    assigned_jobs['assignments'].push({ droneId: drones.first['droneId'], packageId: packages.first['packageId']})
    drones.shift
  end
  packages.shift
end

puts assigned_jobs
