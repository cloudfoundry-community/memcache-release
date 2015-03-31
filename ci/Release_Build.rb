require 'fileutils'

final_build = ARGV[0] == "true"
access_key_id = ARGV[1]
secret_access_key = ARGV[2]

final_release_name = "change-this-release-name"

home_directory = Dir.pwd

puts "Deleting all previous .tgz files in releases and dev_releases."
system("rm -rf releases/#{final_release_name}/*.tgz 2>&1")
exit $?.exitstatus unless $?.exitstatus == 0
system("rm -rf dev_releases/#{final_release_name}/*.tgz 2>&1")
exit $?.exitstatus unless $?.exitstatus == 0

puts "Executing './update'"
system({"HOME" => home_directory}, "proxychains4 ./update 2>&1")
exit $?.exitstatus unless $?.exitstatus == 0

File.open("config/dev.yml", 'w') do |f|
  f.write("---\ndev_name: #{final_release_name}")
end unless File.exist?("config/dev.yml")

release_name = nil

unless final_build
  puts "Creating Dev Release"
  system({"HOME" => home_directory}, "proxychains4 bosh -n --no-color create release --with-tarball  --force 2>&1")
  exit $?.exitstatus unless $?.exitstatus == 0

  puts "Ensuring there is only one *.tgz file in dev_releases directory:"
  raise "Wrong number of tarballs in the dev_releases directory." unless Dir.glob("dev_releases/#{final_release_name}/*.tgz").size == 1

  Dir.glob("dev_releases/#{final_release_name}/*.tgz") do |path|
    puts "Processing tgz from path #{path}"
    release_name = File.basename(path, ".tgz")
  end

  raise "Failed to parse release name from tgz." if release_name.nil?

else
  puts "Creating private.yml"  
  File.open("config/private.yml", 'w') do |f|
    f.write("blobstore:
  s3:
    access_key_id: #{access_key_id}
    secret_access_key: #{secret_access_key}")
  end

  puts "Creating dev release in preparation for final"
  system({"HOME" => home_directory}, "proxychains4 bosh -n --no-color create release 2>&1")
  exit $?.exitstatus unless $?.exitstatus == 0

  puts "Creating final release"
  system({"HOME" => home_directory}, "proxychains4 bosh -n --no-color create release --final --with-tarball --force 2>&1")
  exit $?.exitstatus unless $?.exitstatus == 0

  puts "Ensuring there is only one *.tgz file in release directory:"
  raise "Wrong number of tarballs in the releases directory." unless Dir.glob("releases/#{final_release_name}/*.tgz").size == 1
  
  Dir.glob("releases/#{final_release_name}/*.tgz") do |path|
    puts "Processing tgz from path #{path}"
    release_name = File.basename(path, ".tgz")
  end
  
  raise "Failed to parse release name from tgz." if release_name.nil?

  puts "Adding Changes to git index"
  system("git add . 2>&1")
  exit $?.exitstatus unless $?.exitstatus == 0

  puts "Committing changes to git"
  system("git commit -m 'Add Release #{release_name}' 2>&1")
  exit $?.exitstatus unless $?.exitstatus == 0

  puts "Creating release tag for #{release_name}"
  system("git tag #{release_name} 2>&1")
  exit $?.exitstatus unless $?.exitstatus == 0

  puts "Pull and merge latest repo changes"
  system("git pull --no-edit 2>&1")
  exit $?.exitstatus unless $?.exitstatus == 0

  puts "Pushing master to stash"
  system("git push origin master 2>&1")
  exit $?.exitstatus unless $?.exitstatus == 0
  
  puts "Pushing tag to stash"
  system("git push --tags 2>&1")
  exit $?.exitstatus unless $?.exitstatus == 0
end

puts "Adding Workflow Property #{release_name}"
system("echo '<properties><property name=\"release.name\">#{release_name}</property></properties>' | ahptool setBuildLifeProperties -")
exit $?.exitstatus unless $?.exitstatus == 0