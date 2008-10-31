Gem::Specification.new do |s|
  s.name      = "ticgit"
  s.version   = "0.3.7"
  s.date      = "2008-09-11"
                
  s.authors   = ["Scott Chacon", "Mislav Marohnić", "Flurin Egger"]
  s.email     = "schacon@gmail.com"
  s.summary   = "A distributed ticketing system for Git projects."
  s.homepage  = "http://github.com/schacon/ticgit/wikis"
  
  s.files     = %w( lib/ticgit/base.rb
                    lib/ticgit/cli.rb
                    lib/ticgit/comment.rb
                    lib/ticgit/ticket.rb
                    lib/ticgit.rb
                    bin/ti
                    bin/ticgitweb
                  )
  
  s.bindir = "bin"
  s.executables << "ti"
  s.executables << "ticgitweb"
  # s.require_paths = ["lib", "bin"]
  
  s.has_rdoc = false
  
  s.add_dependency "schacon-git", ["~> 1.0.5"]
  s.add_dependency "sinatra", ["~> 0.3.1"]
  s.add_dependency "wycats-thor", ["~> 0.9.5"]
end
