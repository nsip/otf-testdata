require "json"
require "rubystats"
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

def get_result(s)
  r = rand
  if r < s[:aptitude] - 0.3 then "not displayed"
  elsif r < s[:aptitude] then "intermittent"
  else "fully mastered"
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

def get_sif_students
  students = []
  gen = Rubystats::NormalDistribution.new(0.5, 0.18)
  sessiontoken = "ca6618e3-f17a-42cb-90be-6543b016f489"
  usertoken = "7417b5beee404467b5ac6f9584ee6ec9"
  tk = Base64.encode64("#{sessiontoken}:#{usertoken}").strip.gsub(/\n/, "")
  url = "http://hits.nsip.edu.au/SIF3InfraREST/hits/requests/StudentPersonals?access_token=#{tk}&authenticationMethod=Basic&timestamp=#{Time.now.iso8601}&navigationPage=1&navigationPageSize=1000"
  xml = `curl "#{url}"`
  xml1 = Nokogiri::XML(xml)
  xml1.xpath("//xmlns:StudentPersonal").each do |x|
    given = x.at("./xmlns:PersonInfo/xmlns:Name/xmlns:GivenName")
    surname = x.at("./xmlns:PersonInfo/xmlns:Name/xmlns:FamilyName")
    email = x.at("./xmlns:PersonInfo/xmlns:EmailList/xmlns:Email")
    yrlvl = x.at("./xmlns:MostRecent/xmlns:YearLevel/xmlns:Code")
    students << { 
      name: "#{given.text} #{surname&.text}", email: email&.text, yrlvl: yrlvl&.text,
      aptitude: gen.rng
    }
  end
  students
end

def teachers 
  {
    "1": {name: "Lizabeth Portwood", email: "lp@example.com" },
    "2": {name: "Suk Boger", email: "sb@example.com" },
    "3": {name: "Shara Posner", email: "sp@example.com" },
    "4": {name: "Marietta Maley", email: "mm@example.com" },
    "5": {name: "Vickie Ritzer", email: "vr@example.com" },
    "6": {name: "Marina Paulino", email: "mp@example.com" },
    "7": {name: "Nam Tome", email: "nt@example.com" },
    "8": {name: "Alton Newbill", email: "an@example.com" },
    "9": {name: "Janice Dedrick", email: "jd@example.com" },
    "10": {name: "Marya Sieben", email: "ms@example.com" },
    "11": {name: "Julissa Fewell", email: "jf@example.com" },
    "12": {name: "Margart Hunsicker", email: "mh@example.com" }
  }
end

def observation(i,s)
  r = get_result(s)
  {
    id: UUIDTools::UUID.random_create,
    actor: {
      name: s[:name],
      mbox: "mailto:" + s[:email],
      objectType: "Agent"
    },
    verb: {
      id: "http://adlnet.gov/expapi/verbs/mastered",
      display: {
        "en-US": "mastered"
      }
    },
    object: {
      id: i[:id],
      definition: {
        name: {
          "en-US": i[:code],
        },
        description: {
          "en-US": i[:text]
        },
        type: "http://adlnet.gov/expapi/activities/objective"
      },
      objectType: "Activity"
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
            },
            "type": "http://www.tincanapi.co.uk/activitytypes/grade_classification"
          },
          objectType: "Activity"
        }
      }
    },
    timestamp: "2020-05-01T23",
  }
end

def assessment(i, s, n)
  {
    id: UUIDTools::UUID.random_create,
    actor: {
      name: s[:name],
      mbox: "mailto:" + s[:email],
      objectType: "Agent"
    },
    verb: {
      id: "http://adlnet.gov/expapi/verbs/completed",
      display: {
        "en-US": "completed"
      }
    },
    object: {
      id: "http://www.example.com/assessment/#{n}",
      definition: {
        name: {
          "en-US": "Assessment for #{i[:code]}",
        },
        extensions: {
          "http://id.tincanapi.com/extension/topic": "general"
        },
        type: "http://adlnet.gov/expapi/activities/assessment"
      },
      objectType: "Activity"
    },
    context: {
      instructor: {
        name: teachers[s[:yrlvl].to_sym][:name],
        mbox: "mailto:" + teachers[s[:yrlvl].to_sym][:email],
        objectType: "Agent"
      }
    },
    result: {
      success: (r == "mastered" ? "true" : "false"),
      duration: "P30D",
      extensions: {
        "http://www.tincanapi.co.uk/extensions/result/classification": {
          id: UUIDTools::UUID.random_create,
          definition: {
            name: {
              "en-US": r
            },
            "type": "http://www.tincanapi.co.uk/activitytypes/grade_classification"
          },
          objectType: "Activity"
        }
      }
    },
    timestamp: "2020-05-01T23",
  }
end

def grade(s)
  r = s[:aptitude] + 0.2 + (rand  - 0.5)*0.5
  r = 1 if r > 1
  r = 0 if r < 0
  ret = if r >= 0.8 then "A"
        elsif r >= 0.7 then "B"
        elsif r >= 0.6 then "C"
        elsif r >= 0.5 then "D"
        elsif r >= 0.4 then "E"
        else
          "F"
        end
  [(r * 100).round, ret]
end

def assessment1(i, s, n)
  numbergrade, lettergrade = grade(s)
  {
    id: UUIDTools::UUID.random_create,
    actor: {
      name: s[:name],
      mbox: "mailto:" + s[:email],
      objectType: "Agent"
    },
    verb: {
      id: "http://activitystrea.ms/schema/1.0/satisfy",
      display: {
        "en-US": "satisfied"
      }
    },
    object: {
      id: i[:id],
      definition: {
        name: {
          "en-US": i[:code],
        },
        description: {
          "en-US": i[:text]
        },
        type: "http://adlnet.gov/expapi/activities/objective"
      },
      objectType: "Activity"
    },
    context: {
      instructor: {
        name: teachers[s[:yrlvl].to_sym][:name],
        mbox: "mailto:" + teachers[s[:yrlvl].to_sym][:email],
        objectType: "Agent"
      },
      extensions: {
        "http://id.tincanapi.com/extension/target": {
          id: "http://www.example.com/assessment/#{n}",
          definition: {
            name: {
              "en-US": "Assessment for #{i[:code]}",
            },
            extensions: {
              "http://id.tincanapi.com/extension/topic": "general"
            },
            type: "http://adlnet.gov/expapi/activities/assessment"
          },
          objectType: "Activity"
        }
      }
    },
    result: {
      success: (lettergrade <= "D" ? "true" : "false"),
      score: {
        scaled: numbergrade,
        raw: numbergrade,
        min: 0,
        max: 100,
      },
      duration: "P30D",
      extensions: {
        "http://www.tincanapi.co.uk/extensions/result/classification": {
          id: UUIDTools::UUID.random_create,
          definition: {
            name: {
              "en-US": lettergrade
            },
            "type": "http://www.tincanapi.co.uk/activitytypes/grade_classification"
          },
          objectType: "Activity"
        }
      }
    },
    timestamp: "2020-05-01T23",
  }
end

lp = JSON.parse(File.read("progressions.json"))
lp.each do |s|
  lp_traverse(s, nil, nil, progs)
end

students = get_sif_students()
students_per_yrlvl = {}
students.each do |s|
  students_per_yrlvl[s[:yrlvl]] ||= []
  students_per_yrlvl[s[:yrlvl]] << s
end


def NSIP_observations
  observations = []
  students.each do |s|
    get_indicators(s, progs, 10).each do |i|
      observations << observation(i, s)
    end
  end

  students_per_yrlvl.keys.each do |yr|
    get_indicators(students_per_yrlvl[yr][0], progs, 10).each_with_index do |i, n|
      students_per_yrlvl[yr].each do |s|
        observations << assessment1(i, s, n)
      end
    end
  end
  observations
end

def ESA_observations()
  gemma = {name: "Gemma Boger", email: "gb@example.com" } # Yr 2 English
  ruby = {name: "Ruby Tome", email: "rt@example.com" } # Yr 7 & 8 Maths
  jet = {name: "Jet Zhang", email: "jz@example.com" } # Yr 3 Maths & English
end

#puts JSON.pretty_generate(NSIP_observations())
puts JSON.pretty_generate(ESA_observations())

