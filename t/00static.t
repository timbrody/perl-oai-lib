use Test;

use strict;

BEGIN { plan tests => 20 }

use HTTP::OAI;
ok(1);

# This test harness checks that the library correctly supports
# transparent gateway to static repositories

my $fn = "file:".$ENV{PWD}."/examples/repository.xml";
my $repo = HTTP::OAI::Harvester->new(baseURL=>$fn,debug=>0);
ok($repo);
ok($repo->Identify->version eq '2.0s');
# Removed this test, as paths screw up too much
#ok($repo->Identify->baseURL && $repo->Identify->baseURL eq 'file:///examples/repository.xml');

# Identify
my $id = $repo->Identify;
ok($id->is_success);
ok($id->repositoryName && $id->repositoryName eq 'Demo repository');

# ListMetadataFormats
my $lmdf = $repo->ListMetadataFormats;
ok($lmdf->is_success);
ok(my $mdf = $lmdf->next);
ok($mdf && $mdf->metadataPrefix && $mdf->metadataPrefix eq 'oai_dc');

# ListRecords
my $lr = $repo->ListRecords(metadataPrefix=>'oai_rfc1807');
ok($lr->is_success);
my $rec = $lr->next;
ok($rec && $rec->identifier && $rec->identifier eq 'oai:arXiv:cs/0112017');

# ListIdentifiers
my $li = $repo->ListIdentifiers(metadataPrefix=>'oai_dc');
ok($li->is_success);
my @recs = $li->identifier;
ok(@recs && $recs[-1]->identifier eq 'oai:perseus:Perseus:text:1999.02.0084');

# ListSets
my $ls = $repo->ListSets();
ok($ls->is_success);
my @errs = $ls->errors;
ok(@errs && $errs[-1]->code eq 'noSetHierarchy');

# GetRecord
my $gr = $repo->GetRecord(metadataPrefix=>'oai_dc',identifier=>'oai:perseus:Perseus:text:1999.02.0084');
ok($gr->is_success);
$rec = $gr->next;
ok($rec && $rec->identifier eq 'oai:perseus:Perseus:text:1999.02.0084');

# Errors
$gr = $repo->GetRecord(metadataPrefix=>'oai_dc',identifier=>'invalid');
ok($gr->is_error);
@errs = $gr->errors;
ok(@errs && $errs[0]->code eq 'idDoesNotExist');

$lr = $repo->ListRecords(metadataPrefix=>'invalid');
ok($lr->is_error);
@errs = $lr->errors;
ok(@errs && $errs[0]->code eq 'cannotDisseminateFormat');
