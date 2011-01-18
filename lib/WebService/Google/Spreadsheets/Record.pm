package WebService::Google::Spreadsheets::Record;
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

__PACKAGE__->mk_accessors(qw(etag id title links record_id data));

sub new {
    my $class = shift;
    $class->SUPER::new({
        @_,
    });
}

sub update {
    my ($self, %args) = @_;

    my $e_entry = $self->_create_table_record_xml(%args);

    my $request_url = sprintf $self->links->{edit};
    my $req =  PUT $request_url;
    $req->header('Authorization' =>  $self->authorization);
    $req->header('IF-Match' =>  $self->etag);
    $req->content_type('application/atom+xml');
    my $xml = $e_entry->toString;
    _utf8_off($xml);
    $req->content_length(length $xml);
    $req->content($xml);

    my $res = $self->_request($req) or return;
}

1;




