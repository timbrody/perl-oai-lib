require 5.005;
use ExtUtils::MakeMaker;

# n.b. I put 0.1 as version requirements as I have
# very recent versions, whereas these modules will
# most likely work with older versions of the req.
# modules. TDB

WriteMakefile(
	NAME		=> 'HTTP-OAI',
	VERSION_FROM	=> 'lib/HTTP/OAI.pm',
	EXE_FILES	=> [ qw( bin/oai_browser.pl ) ],
	PREREQ_PM	=> {
				'Encode' => 2.12,
				'XML::LibXML' => 1.60,
				'XML::LibXML::SAX' => 0,
				'XML::SAX::Base' => 1.00,
				'XML::SAX' => 0,
				'URI' => 0,
				'HTTP::Request' => 0,
				'HTTP::Response' => 0,
				'LWP::UserAgent' => 0,
				'Test::More' => 0,
				'CGI' => 0,
			},
	dist		=> { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);
