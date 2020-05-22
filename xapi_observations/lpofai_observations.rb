require "json"
require "rubystats"
require "uuidtools"
require "byebug"
require "nokogiri"
require "base64"

progs = {literacy: {}, numeracy: {}}
def lp_traverse(s, lvl, code, progs, gc)
  return if s.nil?
  lvl0 = s.dig("asn_proficiencyLevel", "prefLabel")
  lvl = lvl0 unless lvl0.nil?
  # eventually we will put indicator codes in
  if s["asn_statementLabel"]["literal"] == "Progression Level"
    code = s.dig("asn_statementNotation", "literal")
  end
  if s["asn_statementLabel"]["literal"] == "Indicator"
    progs.has_key?(lvl) or progs[lvl] = []
    progs[lvl] << { id: s["id"], text: s["text"], code: code, gc: gc }
  end

  s["children"]&.each do |s1|
    lp_traverse(s1, lvl, code, progs, gc)
  end
end

def get_result(s, gc)
  r = rand
  aptitude = gc == :literacy ? s[:lit_aptitude] : s[:num_aptitude]
  if r < aptitude - 0.3 then "not displayed"
  elsif r < aptitude then "intermittent"
  else "fully mastered"
  end
end

def get_indicators(s, progs, n, gc)
  return get_indicators(s, progs, n/2, :literacy) + get_indicators(s, progs, n/2, :numeracy) if gc.nil? && s[:yrlvl].to_i < 11
  return get_indicators(s, progs, n, :literacy) if gc.nil? && s[:yrlvl].to_i >= 11 # numeracy only goes up to level 10
  ret = []
  while ret.size < n and ret.size < progs[gc][s[:yrlvl]].size
    newval = rand(progs[gc][s[:yrlvl]].size)
    ret << newval unless ret.include? newval
  end
  ret.map { |i| progs[gc][s[:yrlvl]][i] }
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
      lit_aptitude: gen.rng, num_aptitude: gen.rng
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

def observation(i, s)
  r = get_result(s, i[:gc])
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

def grade(s, gc)
  aptitude = gc == :literacy ? s[:lit_aptitude] : s[:num_aptitude]
  r = aptitude + 0.2 + (rand  - 0.5)*0.5
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

def assessment1(i, s, n, t)
  numbergrade, lettergrade = grade(s, i[:gc])
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
        name: t[:name],
        mbox: "mailto:" + t[:email],
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

def recommendation(n, t)
  {
    id: UUIDTools::UUID.random_create,
    actor: {
      name: "http://ofai.edu.au",
      mbox: "mailto:ofai@ofai.edu.au",
      objectType: "Agent"
    },  
    verb: {
      id: "http://id.tincanapi.com/verb/promoted",
      display: {
        "en-US": "promoted"
      }   
    },
    object: {
      id: "http://ofai.edu.au/resources/#{n}",
      definition: {
        name: {
          "en-US": "OFAI Resource #{n}"
        },  
        description: {
          "en-US": "OFAI Resource #{n} is a resource"
        },
        type: "http://id.tincanapi.com/activitytype/resource"
      },
      objectType: "Activity"
    },
    context: {
      extensions: {
        "http://id.tincanapi.com/extension/target": {
          name: t[:name],
          mbox: "mailto:#{t[:email]}",
          objectType: "Agent"
        }
      }
    }, 
    timestamp: "2020-05-01T23",
  }
end

def viewed_recommendation(set, n, t) 
  {
    id: UUIDTools::UUID.random_create,
    actor: {
      name: t[:name],
      mbox: "mailto:#{t[:email]}",
      objectType: "Agent"
    },
    verb: {
      id: "http://activitystrea.ms/schema/1.0/experience",
      display: {
        "en-US": "experienced"
      }
    },
    object: set[n][:object],
    context: {
      statement: {
        id: set[n][:id],
        objectType: "StatementRef"
      }
    },
    timestamp: "2020-05-01T23",
  }
end

def viewed_illustration_practice(n, t)
  r = 1
  r = rand if rand < 0.5
  duration = 30
  viewed = (r * duration * 60).divmod(60)

  {
    id: UUIDTools::UUID.random_create,
    actor: {
      name: t[:name],
      mbox: "mailto:#{t[:email]}",
      objectType: "Agent"
    },
    verb: {
      id: "http://activitystrea.ms/schema/1.0/watch",
      display: {
        "en-US": "watched"
      }
    },
    object: {
      id: "http://aitsl.edu.au/illustrations_of_practice/#{n}",
      definition: {
        name: {
          "en-US": "Illustration of Practice #{n}"
        },
        description: {
          "en-US": "Illustration of Practice #{n} is an illustration of practice"
        },
        type: "http://activitystrea.ms/schema/1.0/video",
        extensions: {
          "http://id.tincanapi.com/extension/duration": "P#{duration}M"
        }
      },
      objectType: "Activity"
    },
    result: {
      completion: r == 1 ? "true" : "false",
      duration: "P#{ viewed[0] }M#{ viewed[1].round }S"
    },
    timestamp: "2020-05-01T23",
  }
end

def assign(s, n, t)
  {
    id: UUIDTools::UUID.random_create,
    actor: {
      name: t[:name],
      mbox: "mailto:#{t[:email]}",
      objectType: "Agent"
    },
    verb: {
      id: "http://activitystrea.ms/schema/1.0/assign",
      display: {
        "en-US": "assigned"
      }
    },
    object: {
      id: "http://ofai.edu.au/resources/#{n}",
      definition: {
        name: {
          "en-US": "OFAI Resource #{n}"
        },
        description: {
          "en-US": "OFAI Resource #{n} is a resource"
        },
        type: "http://id.tincanapi.com/activitytype/resource"
      },
      objectType: "Activity"
    },
    context: {
      extensions: {
        "http://id.tincanapi.com/extension/target": {
          name: s[:name],
          mbox: "mailto:#{s[:email]}",
          objectType: "Agent"
        }
      }
    },
    timestamp: "2020-05-01T23",
  }
end

def activity(n, s)
  {
    id: UUIDTools::UUID.random_create,
    actor: {
      name: s[:name],
      mbox: "mailto:#{s[:email]}",
      objectType: "Agent"
    },
    verb: {
      id: "http://adlnet.gov/expapi/verbs/completed",
      display: {
        "en-US": "completed"
      }
    },
    object: {
      id: "http://ofai.edu.au/activity/#{n}",
      definition: {
        name: {
          "en-US": "OFAI Activity #{n}"
        },
        description: {
          "en-US": "OFAI Activity #{n} is an activity"
        },
        type: "http://id.tincanapi.com/activitytype/resource"
      },
      objectType: "Activity"
    },
    result: {
      completion: rand < 0.7 ? "true" : "false"
    },
    timestamp: "2020-05-01T23",
  }
end

def rating_response(r)
  case r
  when 0 then "Salt the earth"
  when 1 then "Dreadful"
  when 2 then "Meh"
  when 3 then "OK"
  when 4 then "Highly recommended"
  when 5 then "Excellent!"
  end
end

def feedback(n, t)
  r = rand(6).floor
  {
    id: UUIDTools::UUID.random_create,
    actor: {
      name: t[:name],
      mbox: "mailto:#{t[:email]}",
      objectType: "Agent"
    },
    verb: {
      id: " http://id.tincanapi.com/verb/rated",
      display: {
        "en-US": "rated"
      }
    },
    object: {
      id: "http://ofai.edu.au/activity/#{n}",
      definition: {
        name: {
          "en-US": "OFAI Activity #{n}"
        },
        description: {
          "en-US": "OFAI Activity #{n} is an activity"
        },
        type: "http://id.tincanapi.com/activitytype/resource"
      },
      objectType: "Activity"
    },
    result: {
      score: {
        raw: r,
        min: 0,
        max: 5,
      },
      response: rating_response(r),
    },
    timestamp: "2020-05-01T23",
  }
end

def alignment_feedback(n, i, t)
  r = rand(6).floor
  {
    id: UUIDTools::UUID.random_create,
    actor: {
       name: t[:name],
      mbox: "mailto:#{t[:email]}",
      objectType: "Agent"
    },
    verb: {
      id: "http://id.tincanapi.com/verb/rated",
      display: {
        "en-US": "rated"
      }
    },
    object: {
      objectType: "SubStatement",
      actor: {
        name: "http://ofai.edu.au",
      mbox: "mailto:ofai@ofai.edu.au",
        objectType: "Agent"
      },
      verb: {
        id: "http://activitystrea.ms/schema/1.0/tag",
        display: {
          "en-US": "tagged"
        }
      },
      object: {
        id: "http://ofai.edu.au/activity/#{n}",
      definition: {
        name: {
          "en-US": "OFAI Activity #{n}"
        },
        description: {
          "en-US": "OFAI Activity #{n} is an activity"
        },
        type: "http://id.tincanapi.com/activitytype/resource"
      },
      objectType: "Activity"
      },
      context: {
        extensions: {
          "http://id.tincanapi.com/extension/target": {
            id: i[:id],
            definition: {
              name: {
                "en-US": i[:code]
              },
              description: {
                "en-US": i[:text]
              },
              type: "http://adlnet.gov/expapi/activities/objective"
            },
            objectType: "Activity"
          }
        }
      }
    },
    result: {
      score: {
        raw: r,
        min: 0,
        max: 5
      },
      response: rating_response(r),
    },
    timestamp: "2020-05-01T23",
  }
end

lp = JSON.parse(File.read("progressions.json"))
# hard coded: [0] = literacy, [1] = numeracy
lp_traverse(lp[0], nil, nil, progs[:literacy], :literacy)
lp_traverse(lp[1], nil, nil, progs[:numeracy], :numeracy)

students = get_sif_students()
students_per_yrlvl = {}
students.each do |s|
  students_per_yrlvl[s[:yrlvl]] ||= []
  students_per_yrlvl[s[:yrlvl]] << s
end


def NSIP_observations(progs, students_per_yrlvl)
  observations = []
  students_per_yrlvl.keys.each do |yr|
    students_per_yrlvl[yr].each do |s|
      get_indicators(s, progs, 10, nil).each do |i|
        observations << observation(i, s)
      end
    end
  end

  students_per_yrlvl.keys.each do |yr|
    get_indicators(students_per_yrlvl[yr][0], progs, 10, nil).each_with_index do |i, n|
      students_per_yrlvl[yr].each do |s|
        observations << assessment1(i, s, n, teachers[s[:yrlvl].to_sym])
      end
    end
  end
  observations
end

def ESA_observations(progs, students_per_yrlvl)
  gemma = {name: "Gemma Boger", email: "gb@example.com" } # Yr 2 English
  ruby = {name: "Ruby Tome", email: "rt@example.com" } # Yr 7 & 8 Maths
  jet = {name: "Jet Zhang", email: "jz@example.com", 
         yrlvl: "3", lit_aptitude: 0.3, num_aptitude: 0.8 } # Yr 3 Maths & English
  gemmastudents = students_per_yrlvl["2"]
  rubystudents = students_per_yrlvl["7"] + students_per_yrlvl["8"]
  all_students = gemmastudents + rubystudents + [ jet ]
  gemmastudents += [ jet ]
  rubystudents += [ jet ]

  data = []

  all_students.each do |s|
    get_indicators(s, progs, 10, nil).each do |i|
      data << observation(i, s)
    end
  end

  get_indicators(gemmastudents[0], progs, 10, :literacy).each_with_index do |i, n|
    gemmastudents.each do |s|
      data << assessment1(i, s, n, gemma)
    end
  end

  get_indicators(rubystudents[0], progs, 10, :numeracy).each_with_index do |i, n|
    rubystudents.each do |s|
      data << assessment1(i, s, n, ruby)
    end
  end

  gemma_recommendations = []
  (1..10).each do |n|
    gemma_recommendations << recommendation(n, gemma)
  end
  ruby_recommendations = []
  (100..110).each do |n|
    ruby_recommendations << recommendation(n, ruby)
  end
  data += gemma_recommendations
  data += ruby_recommendations

  (0..4).each do |n|
    data << viewed_recommendation(gemma_recommendations, n, gemma)
  end
  (0..4).each do |n|
    data << viewed_recommendation(ruby_recommendations, n, ruby)
  end

  (1..10).each do |n|
    data << viewed_illustration_practice(n, gemma)
  end
  (1..10).each do |n|
    data << viewed_illustration_practice(n, ruby)
  end

  (1..3).each do |n|
    gemmastudents.each do |s|
      data << assign(s, n, gemma)
    end
  end

  (100..102).each do |n|
    rubystudents.each do |s|
      data << assign(s, n, ruby)
    end
  end

  (200..202).each do |n|
    all_students.each do |s|
      data << activity(n, s)
    end
  end

  (1..5).each do |n|
    data << feedback(n, gemma)
  end
  (100..104).each do |n|
    data << feedback(n, ruby)
  end

  (1..5).each do |n|
    data << alignment_feedback(n,  progs[:literacy]["2"][0], gemma)
  end
  (100..104).each do |n|
    data << alignment_feedback(n, progs[:numeracy]["7"][0], ruby)
  end

  data
end

#puts JSON.pretty_generate(NSIP_observations(progs, students_per_yrlvl))
puts JSON.pretty_generate(ESA_observations(progs, students_per_yrlvl))

