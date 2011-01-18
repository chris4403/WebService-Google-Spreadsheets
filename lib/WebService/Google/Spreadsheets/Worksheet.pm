package WebService::Google::Spreadsheets::Worksheet;
use strict;
use warnings;
use base qw(WebService::Google::Spreadsheets::Base);
use WebService::Google::Spreadsheets::Base;

use Carp;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use XML::LibXML;
use UNIVERSAL::isa;
use Data::Dumper;

__PACKAGE__->mk_accessors(qw(id title worksheet_id spreadsheet_key));

sub new {
    my $class = shift;
    $class->SUPER::new({
        @_,
    });
}

sub create_table {
    my ($self, %args) = @_;
    my $param = {
        worksheet_name => $self->title,
        %args
    };
    my $e_entry = $self->_create_table_xml(%$param);

    my $request_url = sprintf ('https://spreadsheets.google.com/feeds/%s/tables', $self->spreadsheet_key);
    my $req =  POST $request_url;
    $req->header('Authorization' => $self->authorization);
    $req->content_type('application/atom+xml');
    my $xml = $e_entry->toString;
    _utf8_off($xml);
    $req->content_length(length $xml);
    $req->content($xml);

    my $res = $self->_request($req) or return;
}


1;


