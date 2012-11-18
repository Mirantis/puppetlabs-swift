require 'puppet'
describe Puppet::Type.type(:ring_account_device) do

  it 'should fail if the name has no ":"' do
    expect {
      Puppet::Type.type(:ring_account_device).new(:name => 'foobar')
    }.to raise_error(Puppet::Error, /should contain address:port/)
  end
end
