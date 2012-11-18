# swift_mountponts.rb

$result = ""

mounted_devs = %x[df |grep '/srv/node']
mounted_devs.split("\n").each do |mountpoint|
  dev, weight = mountpoint.split(/\b/).values_at(-1, 5)
  if dev and weight.strip !=""
    $result += dev + " " + weight.to_i.fdiv(10485760).ceil.to_s + "\n"
  end
end

Facter.add("swift_mountpoints") do
 setcode do
   $result
 end
end
