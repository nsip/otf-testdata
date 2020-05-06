require "json"
require "uuidtools"
require "byebug"
require "nokogiri"
require "base64"

progs = {}
def lp_traverse(s, lvl, code, progs)
  return if s.nil?
  lvl0 = s.dig("asn_proficiencyLevel", "prefLabel")
  lvl = lvl0 unless lvl0.nil?
  # eventually we will put indicator codes in
  if s["asn_statementLabel"]["literal"] == "Progression Level"
    code = s.dig("asn_statementNotation", "literal")
  end
  if s["asn_statementLabel"]["literal"] == "Indicator"
    progs.has_key?(lvl) or progs[lvl] = []
    progs[lvl] << { id: s["id"], text: s["text"], code: code }
  end

  s["children"]&.each do |s1|
    lp_traverse(s1, lvl, code, progs)
  end
end

def get_result
  r = rand
  if r < 0.1 then "not displayed"
  elsif r < 0.3 then "intermittent"
  else "mastered"
  end
end

def get_indicators(s, progs, n)
  ret = []
  while ret.size < n and ret.size < progs[s[:yrlvl]].size
    newval = rand(progs[s[:yrlvl]].size)
    ret << newval unless ret.include? newval
  end
  ret.map { |i| progs[s[:yrlvl]][i] }
end

=begin
students = []
File.open("students.txt", "r") do |f|
  f.each_line do |l|
    a = l.strip.split(/,/)
    students << {name: a[0], email: a[1], yrlvl: a[2] }
  end
end
=end

def get_sif_students
  students = []
  sessiontoken = "ca6618e3-f17a-42cb-90be-6543b016f489"
  usertoken = "7417b5beee404467b5ac6f9584ee6ec9"
  tk = Base64.encode64("#{sessiontoken}:#{usertoken}").strip.gsub(/\n/, "")
  url = "http://hits.nsip.edu.au/SIF3InfraREST/hits/requests/StudentPersonals?access_token=#{tk}&authenticationMethod=Basic&timestamp=#{Time.now.iso8601}&navigationPage=1&navigationPageSize=100"
  xml = `curl "#{url}"`
  xml1 = Nokogiri::XML(xml)
  xml1.xpath("//xmlns:StudentPersonal").each do |x|
    given = x.at("./xmlns:PersonInfo/xmlns:Name/xmlns:GivenName")
    surname = x.at("./xmlns:PersonInfo/xmlns:Name/xmlns:FamilyName")
    email = x.at("./xmlns:PersonInfo/xmlns:EmailList/xmlns:Email")
    yrlvl = x.at("./xmlns:MostRecent/xmlns:YearLevel/xmlns:Code")
    students << {name: "#{given.text} #{surname&.text}", email: email&.text, yrlvl: yrlvl&.text }
  end
  students
end

students = get_sif_students()

lp = JSON.parse(File.read("progressions.json"))
lp.each do |s|
  lp_traverse(s, nil, nil, progs)
end

#warn progs

observations = []
students.each do |s|
  get_indicators(s, progs, 10).each do |i|
    r = get_result
    observations << {
      id: UUIDTools::UUID.random_create,
      actor: {
        name: s[:name],
        mbox: s[:email]
      },
      verb: {
        id: "http://adlnet.gov/expapi/verbs/mastered",
        display: {
          "en-US": "mastered"
        }
      },
      object: {
        id: i[:id],
        definition: i[:text],
        extensions: {
          "learning Progression": i[:code]
        }
      },
      result: {
        success: (r == "mastered" ? "true" : "false"),
        duration: "P30D",
        extensions: {
          # https://github.com/adlnet/xapi-authored-profiles/blob/master/tincan/tincan.ttl
          "http://www.tincanapi.co.uk/extensions/result/classification": {
            id: UUIDTools::UUID.random_create,
            definition: {
              name: {
                "en-US": r
              }
            },
            objectType: "http://www.tincanapi.co.uk/activitytypes/grade_classification"
          }
        }
      },
      timestamp: "2020-05-01T23",
    }
  end
end

puts JSON.pretty_generate(observations)

