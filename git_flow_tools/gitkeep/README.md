# GitKeep.

The objective of this tool is automate and speed up common operations for iOS development.

For auto complete functionality, copy the 2 .git*-completion files to your ~/ directory, and add the following to your bash_profile:

`if [ -f ~/.git-completion.bash ]; then
  . ~/.git-completion.bash
fi`

`if [ -f ~/.gittool-completion.bash ]; then
  . ~/.gittool-completion.bash
fi`

Run bundler install

Then, run the setup commands to configure for use.

For any operations that involve GitHub, supply your oauth token from GitHub (aka 'Personal access tokens' in GitHub) and this will be added to your keychain along with an email address you want to send from, using the command:

`./gitkeep setup_oauth -o [OAUTH_TOKEN]`

For any operations that involve sending an email, use the following commands

`./gitkeep setup_email -e [EMAIL_ADDRESS]`

You will then be promoted for your email password which will be stored in your keychain:

`Enter email password:`

And then you're ready to use the script.

## Merging.
To perform an interactive merge:

`./gitkeep merger --base_branch [BASE_BRANCH_NAME] --merge_branch [BRANCH_TO_BE_MERGED_IN]`

The command can also be given with -a, and a series of parameters to automatically run through the merge request, except for any conflicts which will need manually resolved.
-p will push the created branch to origin
-g will generate a pull request (requires -p to be selected)
-f instead will not generate a pull request, but will complete the merge with the base branch.
-o [OAUTH_TOKEN] will over ride the configured oauth token.

you can then revert back to the base_branch using:

`./gitkeep clean --base_branch [BASE_BRANCH_NAME] --merge_branch [BRANCH_TO_BE_MERGED_IN] -p`

-p is required to ensure the remote branch is deleted.

##Cutting an iOS release

The tool allows the cutting of a release on the iOS repository and bumps the version branch in develop and raises a PR, then cuts a release branch.

It will also update jenkins and github status checks to monitor the new branch, and publish the information to the iOS dashboard.
`./gitkeep cut_release -p [PREVIOUS_VERSION] -v [VERSION_TO_BE_CUT] -n [NEXT_VERSION]`
