Puppet::Type.newtype(:ring_container_device) do
  require 'ipaddr'

  ensurable

  newparam(:name, :namevar => true) do
    validate do |value|
      address = value.split(':')
      raise(Puppet::Error, "name should contain address:port - got #{value}") unless address.size == 2
      IPAddr.new(address[0])
    end
  end

  newparam(:mountpoints) do
    desc "mountpoints and weight "
  end

  newproperty(:zone)

  newproperty(:meta)

  [:id, :partitions, :balance].each do |param|
    newproperty(param) do
      validate do |value|
        raise(Puppet::Error, "#{param} is a read only property, cannot be assigned")
      end
    end
  end

end
