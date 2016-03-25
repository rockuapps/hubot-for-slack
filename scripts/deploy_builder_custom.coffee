# Description:
#  Create pull request from develop to master.
#
# Dependencies:
#   "githubot": "0.4.x"
#
# Configuration:
# HUBOT_GITHUB_TOKEN
# HUBOT_GITHUB_USER
# HUBOT_GITHUB_ORG
# HUBOT_DEPLOY_MESSAGE
# HUBOT_NO_DIFFERENCE_MESSAGE
# HUBOT_PR_EXISTS_MESSAGE
# HUBOT_BRANCH_FROM
# HUBOT_BRANCH_TO
#
# Commands:
#   hubot deploy <repo>
#
# Author:
#   ryonext
#   nozayasu

module.exports = (robot) ->
  github = require("githubot")(robot)

  writeMessage = (msg, response, deployMessage) ->
    commits_url = "#{response.commits_url}?per_page=100"
    github.get response.commits_url, (commits) ->
      prBody = "These PRs will be released.\n"

      needIssueLink = true
      if needIssueLink
        robot.logger.debug "startIssueLink"
        async = require('async')
        async.eachSeries(commits,
          ((commit, next) ->
            if commit.commit.message.match(/Merge pull request/)
              prBody += "- [ ] #{commit.commit.message.replace(/\n\n/g, ' ').replace(/Merge pull request /, '')} by @#{commit.author.login}\n"
              id = commit.commit.message.match(/^.+#(\d+).+/)[1]
              github.get "/repos/rockuapps/aerosmith/pulls/#{id}", (response) ->
                if target = response.body.match(/.*connect.+#(\d+)/)
                  issueId = target[1]
                  prBody += " * 目的: ##{issueId}\n"
                next()
            else
              next()
          ), -> (
            update_data = { body: prBody }
            github.patch response.url, update_data, (update_response) ->
              msg.send deployMessage
              msg.send update_response.html_url
          )
        )
      else
        for commit in commits
          unless commit.commit.message.match(/Merge pull request/)
            continue
          pr_body += "- [ ] #{commit.commit.message.replace(/\n\n/g, ' ').replace(/Merge pull request /, '')} by @#{commit.author.login}\n"

        update_data = { body: pr_body }
        github.patch response.url, update_data, (update_response) ->
          msg.send deployMessage
          msg.send update_response.html_url

  createPullRequest = (url, data, msg) ->
    github.post url, data, (response) ->
      writeMessage(msg, response, (process.env.HUBOT_DEPLOY_MESSAGE || "Please deploy it!"))

  updatePrSummary = (url, msg) ->
    github.get url, (response) ->
      writeMessage(msg, response, "updated PR summary")

  robot.respond /deploy (\S+)\s*(\S*)?\s*(\S*)?/i, (msg) ->
    robot.logger.debug "test"
    repo = msg.match[1]
    branch_from = msg.match[2] || process.env.HUBOT_BRANCH_FROM || "develop"
    branch_to = msg.match[3] || process.env.HUBOT_BRANCH_TO || "master"
    github.handleErrors (response) ->
      if response.body.indexOf("No commits") > -1
          msg.send process.env.HUBOT_NO_DIFFERENCE_MESSAGE || "There is no difference between two branches :("
    url_api_base = "https://api.github.com"
    data = {
      "title": "deploy",
      "head": branch_from,
      "base": branch_to
    }
    ghOrg = process.env.HUBOT_GITHUB_ORG
    url = "#{url_api_base}/repos/#{ghOrg}/#{repo}/pulls"
    github.get url, data, (response) ->
      if response.length > 0
        api_url = "#{url_api_base}/repos/#{ghOrg}/#{repo}/pulls/#{response[0].number}"
        msg.send process.env.HUBOT_PR_EXISTS_MESSAGE || "This pull request already exists."
        updatePrSummary(api_url, msg)
      else
        createPullRequest(url, data, msg)

  robot.respond /update summary of deploy (\w+) (\d+)/i, (msg) ->
    repo = msg.match[1]
    number = msg.match[2]
    url_api_base = "https://api.github.com"
    ghOrg = process.env.HUBOT_GITHUB_ORG
    url = "#{url_api_base}/repos/#{ghOrg}/#{repo}/pulls/#{number}"
    updatePrSummary(url)
