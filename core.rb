require 'octokit'
require 'yaml'

REPO       = 'democratic-self-evolving-software/core'
SCRIPT_DIR = File.expand_path '..', __FILE__
CREDS_YML  = File.join SCRIPT_DIR, 'credentials.yml'

def most_popular_pull_request
  count = Struct.new(:votes, :total)
  max   = count.new(0, 0)
  Octokit.pulls(REPO, state: 'open').inject(nil) do |candidate, pr|
    next candidate unless Octokit.pull_request(REPO, pr.number).mergeable

    curr = count.new(0, 0)
    Octokit.issue_comments(REPO, pr.number).each do |comment|
      if (m = /\B([+-]\d)\b/.match(comment.body)) && (v = m[1].to_i)
        curr.votes += v if -1 <= v && v <= 2
      end

      curr.total += 1
    end

    if curr.votes > max.votes || (curr.votes == max.votes && curr.total > max.total)
      max = curr
      pr
    else
      candidate
    end
  end
end

def democratic_merge
  unless File.exists? CREDS_YML
    puts 'No credentials provided for repo.'
    return
  end

  creds = YAML.load_file CREDS_YML

  Octokit.configure do |c|
    c.login    = creds['login']
    c.password = creds['password']
  end

  candidate = most_popular_pull_request

  if candidate
    puts 'We have a winner:'
    puts "PR \##{candidate.number} with #{max.votes} votes out of #{max.total} comment!"
    puts "Merging..."

    Octokit.merge_pull_request(REPO, candidate.number, 'merged by public decision')
  else
    puts 'No decision made today.'
  end
end

def self_update
  Dir.chdir(SCRIPT_DIR) do
    system 'git pull'
  end
end

democratic_merge
self_update
