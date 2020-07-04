require 'utils'
require 'time'

FILE_TIME_FMT = '%Y%m%dT%H%M%SZ'
BACKUP_DIR_RE = /^\d.+T.+Z$/
LOG = Utils::Log.new

today = Date.today
ARGV.each do |dir|
  dir =~ /:(\d+)$/ or raise ArgumentError, "usage: <dir>:<days> [...]"
  dir, max_days = $`, $1.to_i
  log = LOG[dir, retention: "#{max_days}d"]

  paths = log.info("getting backups older than %d days old" % max_days) {
    JSON.parse `rclone lsjson "#{dir}"`.tap {
      $?.success? or raise "rclone lsjson failed"
    }
  }.select { |e|
    File.basename(e.fetch("Name"), ".*") =~ BACKUP_DIR_RE or next false
    date = Time.strptime($&+"UTC", FILE_TIME_FMT+"%Z").getlocal.to_date
    today - date > max_days
  }.map { |e|
    "#{dir}/#{e.fetch "Path"}"
  }
  log.info "found %d old entries" % [paths.size]
    
  paths.sort.each do |path|
    log.info "deleting #{path}" do
      system "rclone", "purge", path or raise "rclone purge failed"
    end
  end
end
