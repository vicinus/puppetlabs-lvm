require 'master_manipulator'
require 'lvm_helper'
require 'securerandom'

test_name "FM-4614 - C96573 - create logical volume with property 'ensure' and without 'name'"

#initilize
pv = '/dev/sdc'
vg = "VolumeGroup_" + SecureRandom.hex(2)
lv = "LogicalVolume_" + SecureRandom.hex(3)

# Teardown
teardown do
  confine_block(:except, :roles => %w{master dashboard database}) do
    agents.each do |agent|
      remove_all(agent, pv, vg, lv)
    end
  end
end

pp = <<-MANIFEST
physical_volume {'#{pv}':
  ensure  => present,
}
->
volume_group {'#{vg}':
  ensure            => present,
  physical_volumes  => '#{pv}',
}
->
logical_volume{'#{lv}':
  ensure        => present,
  volume_group  => '#{vg}',
  size          => '800M',
}
MANIFEST

step 'Inject "site.pp" on Master'
site_pp = create_site_pp(master, :manifest => pp)
inject_site_pp(master, get_site_pp_path(master), site_pp)

step 'Run Puppet Agent to create logical volumes'
confine_block(:except, :roles => %w{master dashboard database}) do
  agents.each do |agent|
    on(agent, puppet('agent -t --environment production'), :acceptable_exit_codes => [0,2]) do |result|
      assert_no_match(/Error:/, result.stderr, 'Unexpected error was detected!')
    end

    step "Verify the logical volume  is created: #{lv}"
    verify_if_created?(agent, 'logical_volume', lv, vg)
  end
end
