module.exports = (robot) ->

  robot.hear "Failed: (.*)'s build", (msg) ->
    msg.send "おちたよー @#{msg.match[1]}"

