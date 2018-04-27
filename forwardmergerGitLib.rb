#!/usr/bin/ruby -w
require 'net/http'
require 'json'
require 'keyring'
require 'optparse'
require 'ostruct'


$help_text = "Ruby script to perform a forward merge on shopkeeps ipad-register repo. Run inside the repo.

Running command:

Either:

Add the oauth password to the key chain

./forwardmerger.rb --setup --password [INSERT_OAUTH_KEY_HERE]

And then execute your merge
./forwardmerger.rb [-l branch_you_are_on] [-t branch_to_be_merged_in]

OR

Put your oauth in the command itself
./forwardmerger.rb -l [branch_you_are_on] -t [branch_to_be_merged_in] --password [INSERT_OAUTH_KEY_HERE]

Conflicts

Conflicts with the merge will cause the script to exit. You must then resolve
the conflicts and commit the changes. You do not need to push. you must then
run the command again with the --resolved option:

./forwardmerger.rb [-l branch_you_are_on] [-t branch_to_be_merged_in] --resolved

Clean

reverse the attempt to forward merge. This will delete the created
branch, abort the merge and checkout the branch thats the first
parameter. By doing so gihub will close the Pull Request if one was created.
Some fatal logging may not be fatal. The clean function is a
brute force method that you might want to check after.

./forwardmerger.rb [-l branch_you_are_on] [-t branch_to_be_merged_in] --clean

How this script normally works:

Builds the forward merge branch name
git fetch
check result of fetch
git pull
check result of pull
checkout the to_be_merged_in branch, to verify it exists.
create the new forward merge branch
perform merge
(--resolved only runs from this point)
push to origin
create pull request
"

options = OpenStruct.new


OptionParser.new do |opt|
  opt.on('-p', '--password PASSWORD', 'The open_auth token for authentication on github') { |o| options.password = o }
  opt.on('-s', '--setup', 'Run with setup to do initial keychain entry') {options.setup = true }
  opt.on('-l', '--local_branch LOCALBRANCH', 'name of the local branch to be merged into') { |o| options.current_branch = o }
  opt.on('-t', '--to_be_merged TOBEMERGED', 'The name of the branch to be merged in') { |o| options.to_be_merged_in = o }
  opt.on('-c', '--clean', 'Clean up a failed, incomplete or unwanted merge and pull request') {options.clean = true }
  opt.on('-r', '--resolved', 'Finish an incomplete pull request due to a merge conflict.') {options.resolved = true }
  opt.on_tail('-h', '--help', 'Shows the help text') do
  puts opt
  puts $help_text
  exit
end
end.parse!

keyring = Keyring.new
if options.setup == true
    keyring.set_password('merge_script', 'dstothers', options.password)
    puts "password set"
    exit
end

if (defined?(options.current_branch)).nil? || (defined?(options.to_be_merged_in)).nil?
   puts "Incomplete parameters - please read the handy help text:"
   puts $help_text
   exit
end

$current_branch = options.current_branch
$to_be_merged_in_branch = options.to_be_merged_in
puts "SCRIPT_LOGGER:: Merging #$to_be_merged_in_branch into #$current_branch"

$forward_branch = "forward-merge-#$to_be_merged_in_branch-to-#$current_branch"


if options.clean == true
    puts "SCRIPT_LOGGER:: resetting back to #$current_branch"
    system("git merge --abort")
    system("git checkout #$current_branch")
    system("git branch -D #$forward_branch")
    system("git push origin --delete #$forward_branch")
    puts "SCRIPT_LOGGER:: Any merge in progress was aborted, and the created branch deleted."
    exit
end

if options.resolved != true

puts "SCRIPT_LOGGER:: Forward merge branch will be called #$forward_branch"

if true != system('git fetch')
    puts "SCRIPT_LOGGER:: fetch is broken"
    exit
else
    puts "SCRIPT_LOGGER:: Fetched latest successfully"
end

#This pull request bit is messy and I hate it but I couldn't get it to match the hard coded string for no reference/matching repo
$pull_result = %x(git pull 2>&1)
puts $pull_result
$matched_result = $pull_result.split("with the ref").grep(Regexp.new("Your configuration specifies"))
$error_case = "Your configuration specifies to merge with the ref".split("with the ref").grep(Regexp.new("Your configuration specifies"))
$matched_result_2 = $pull_result.split("current branch").grep(Regexp.new("There is no tracking"))
$error_case_2 = "There is no tracking information for the current branch".split("current branch").grep(Regexp.new("There is no tracking"))
$expect_pull_result = "Already up-to-date.\n"


if $expect_pull_result == $pull_result
    puts "SCRIPT_LOGGER:: Branch already up to date"
elsif $error_case == $matched_result
    puts "SCRIPT_LOGGER:: This branch (#$current_branch) no longer exists on the repo but is still tracking. Unable to create a pull request"
    exit
elsif $error_case_2 == $matched_result_2
    puts "SCRIPT_LOGGER:: This branch (#$current_branch) does not exist on the repository. Unable to create a push request."
    exit
else
    puts "SCRIPT_LOGGER:: Pull is broken - \n #$pull_result"
    exit
end

if true != system("git checkout -b #$current_branch origin/#$current_branch")
    puts "SCRIPT_LOGGER:: Failed to checkout #$current_branch from remote, checking if locally available"
    if true != system("git checkout #$current_branch")
        puts "SCRIPT_LOGGER:: Failed to checkout branch locally, unable to continue"
        exit
    end
else
    puts "SCRIPT_LOGGER Successfully checked out the current branch"
end

if true != system("git checkout -b #$forward_branch")
     puts "SCRIPT_LOGGER:: Failed to create new branch."
     exit
else
     puts "SCRIPT_LOGGER:: Branch created"
end

if true != system("git merge origin/#$to_be_merged_in_branch")
    puts "SCRIPT_LOGGER:: unable to merge - check output"
    exit
else
    puts "SCRIPT_LOGGER:: Merged into #$forward_branch"
end

end

if true != system("git push --set-upstream origin #$forward_branch")
    puts "SCRIPT_LOGGER:: unable to push to origin - check error"
    exit
else
    puts "SCRIPT_LOGGER:: Pushed #$forward_branch to origin"
end

puts "SCRIPT_LOGGER:: Creating pull request"


$uri = URI("https://api.github.com/repos/stotherd/yodaspeak/pulls")
$req = Net::HTTP::Post.new($uri, 'Content-Type' => 'application/json')

#Lets remove the token here... shall we?
$password = keyring.get_password('merge_script', 'dstothers')

if($password == false)
  if (defined?(options.password)).nil?
    puts "No password configured - unable to continue"
    exit
  else
    $password = options.password
  end

end

$req['Authorization'] = "token #$password"




$title = "Automated pull request of #$forward_branch into #$current_branch"
$body = "Automated pull request of #$forward_branch, a forward merge of #$to_be_merged_in_branch into #$current_branch, into the #$current_branch branch"

$req.body = {title: $title, body: 'Automated pull request', head: $forward_branch, base: $current_branch}.to_json


$res = Net::HTTP.start($uri.host, $uri.port, :use_ssl => $uri.scheme == 'https') {|http| http.request($req)}

puts $res.body
