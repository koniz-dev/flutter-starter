require File.expand_path('fastlane/release_environment')
['https://example.com?x@acme.io', 'https://example.com#@acme.io', 'https://example.com..',
 'https://api.example.com../x', 'HTTPS://API.EXAMPLE.COM/v1', 'https://user@pw@api.example.com:8443',
 'https://acme.io?x@example.com', 'https://acme.io/v1#@example.com', 'https://user@acme.io:8443/v1',
 'https://@/v1', 'http://api.myco.com', 'ftp://api.myco.com', 'https://api.myco.com /x',
 'https://api.ex%61mple.com', 'https://api.example.com\\@good.com', 'https://api.myco.com'].each do |u|
  begin
    puts "#{u.ljust(42)} -> accepted: #{ReleaseEnvironment.for_environment('production', u)}"
  rescue ArgumentError => e
    puts "#{u.ljust(42)} -> refused: #{e.message}"
  end
end
