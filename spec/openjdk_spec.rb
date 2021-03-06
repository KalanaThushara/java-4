require 'spec_helper'

describe 'java::openjdk' do
  platforms = {
    'debian-8.10' => {
      'packages' => ['openjdk-8-jdk', 'openjdk-8-jre-headless'],
      'update_alts' => true,
    },
    'debian-9.1' => {
      'packages' => ['openjdk-8-jdk', 'openjdk-8-jre-headless'],
      'update_alts' => true,
    },
    'centos-6.9' => {
      'packages' => ['java-1.8.0-openjdk', 'java-1.8.0-openjdk-devel'],
      'update_alts' => true,
    },
    'centos-7.4.1708' => {
      'packages' => ['java-1.8.0-openjdk', 'java-1.8.0-openjdk-devel'],
      'update_alts' => true,
    },
  }

  platforms.each do |platform, data|
    parts = platform.split('-')
    os = parts[0]
    version = parts[1]
    context "On #{os} #{version}" do
      let(:chef_run) { ChefSpec::SoloRunner.new(platform: os, version: version).converge(described_recipe) }

      it "installs packages #{data['packages']}" do
        expect(chef_run).to install_package(data['packages'])
        expect(chef_run.package(data['packages'])).to notify('log[jdk-version-changed]')
      end

      it 'should include the notify recipe' do
        expect(chef_run).to include_recipe('java::notify')
      end

      it 'sends notification to update-java-alternatives' do
        if data['update_alts']
          expect(chef_run).to set_java_alternatives('set-java-alternatives')
        else
          expect(chef_run).to_not set_java_alternatives('set-java-alternatives')
        end
      end
    end
  end

  describe 'conditionally includes set attributes' do
    context 'when java_home and openjdk_packages are set' do
      let(:chef_run) do
        runner = ChefSpec::SoloRunner.new(
          platform: 'ubuntu',
          version: '16.04'
        )
        runner.node.override['java']['java_home'] = '/some/path'
        runner.node.override['java']['openjdk_packages'] = %w(dummy stump)
        runner.converge(described_recipe)
      end

      it 'does not include set_attributes_from_version' do
        expect(chef_run).to_not include_recipe('java::set_attributes_from_version')
      end
    end

    context 'when java_home and openjdk_packages are not set' do
      let(:chef_run) do
        runner = ChefSpec::SoloRunner.new(
          platform: 'ubuntu',
          version: '16.04'
        )
        runner.converge(described_recipe)
      end

      it 'does not include set_attributes_from_version' do
        expect(chef_run).to include_recipe('java::set_attributes_from_version')
      end
    end
  end

  describe 'license acceptance file' do
    { 'centos' => '6.8', 'ubuntu' => '16.04' }.each_pair do |platform, version|
      context platform do
        let(:chef_run) do
          ChefSpec::SoloRunner.new(platform: platform, version: version).converge('java::openjdk')
        end

        it 'does not write out license file' do
          expect(chef_run).not_to create_file('/opt/local/.dlj_license_accepted')
        end
      end
    end

    describe 'default-java' do
      context 'ubuntu' do
        let(:chef_run) do
          ChefSpec::SoloRunner.new(
            platform: 'ubuntu',
            version: '16.04'
          ).converge(described_recipe)
        end

        it 'includes default_java_symlink' do
          expect(chef_run).to include_recipe('java::default_java_symlink')
        end
      end

      context 'centos' do
        let(:chef_run) do
          ChefSpec::SoloRunner.new(
            platform: 'centos',
            version: '6.8'
          ).converge(described_recipe)
        end

        it 'does not include default_java_symlink' do
          expect(chef_run).to_not include_recipe('java::default_java_symlink')
        end
      end
    end
  end
end
