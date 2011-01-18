package WebService::Google::Spreadsheets::Table;
use strict;
use warnings;
use base qw(WebService::Google::Spreadsheets::Base);
use WebService::Google::Spreadsheets::Base;
use WebService::Google::Spreadsheets::Record;
use List::Rubyish;
use Carp;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use XML::LibXML;
use UNIVERSAL::isa;
use Data::Dumper;

__PACKAGE__->mk_accessors(qw(etag id title summary worksheet_name num_rows links table_number spreadsheet_key));

sub new {
    my $class = shift;
    $class->SUPER::new({
        @_,
    });
}

sub modify {
    my ($self, %args) = @_;
    my $param = {
        worksheet_name => $self->worksheet_name,
        %args,
    };
    my $e_entry = $self->_create_table_xml(%$param);

    my $req =  PUT $self->links->{edit};
    $req->header('Authorization' =>  $self->authorization);
    $req->header('IF-Match' =>  $self->etag);
    $req->content_type('application/atom+xml');
    my $xml = $e_entry->toString;
    _utf8_off($xml);
    $req->content_length(length $xml);
    $req->content($xml);

    my $res = $self->_request($req) or return;
}

sub records {
    my ($self, %args) = @_;
    $self->retrieve_records;
}
sub retrieve_records {
    my ($self, %args) = @_;
    my $uri = $self->_table_records_uri(%args);

    my $res = $self->_request(
        GET $uri,
        Authorization => $self->authorization,
    ) or return;

    $self->_parse_table_records_xml($res->content);
}

sub create_record {
    my ($self, %args) = @_;
    my $param = {
        etag => $self->etag,
        %args,
    };
    my $e_entry = $self->_create_table_record_xml(%$param);

    my $request_url = sprintf 'https://spreadsheets.google.com/feeds/%s/records/%s',
            $self->spreadsheet_key,
            $self->table_number;
    my $req =  POST $request_url;
    $req->header('Authorization' =>  $self->authorization);
    $req->content_type('application/atom+xml');
    my $xml = $e_entry->toString;
    _utf8_off($xml);
    $req->content_length(length $xml);
    $req->content($xml);

    my $res = $self->_request($req) or return;
}

sub _table_records_uri {
    my ($self, %args) = @_;
    my $query = $args{query} || "";
    my $uri = URI->new(
                sprintf 'https://spreadsheets.google.com/feeds/%s/records/%s',
                    $self->spreadsheet_key, $self->table_number
              );
    $uri->query_form(sq => $query) if $query;
    $uri;
}

sub _parse_table_records_xml {
    my ($self, $string) = @_;
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_string($string);
    my $records = List::Rubyish->new;
    my $entries = $doc->getElementsByTagName('entry');
    foreach my $entry (@$entries) {
        my $record = WebService::Google::Spreadsheets::Record->new(
            ua          => $self->ua,
            authorization => $self->authorization,
            email       => $self->email,
            password    => $self->password,
            etag        => $entry->getAttribute('gd:etag'),
            id          => $entry->getElementsByTagName('id')->[0]->textContent,
            title       => $entry->getElementsByTagName('title')->[0]->textContent,
            links       => {map { $_->getAttribute('rel') => $_->getAttribute('href')} $entry->getElementsByTagName('link')},
            record_id   =>  map ($_->textContent =~ /\/([\d\w]*)$/ ,$entry->getElementsByTagName('id')->[0]),
            data        => [ map {{
                index => $_->getAttribute('index'),
                name  => $_->getAttribute('name'),
                value => ($_->textContent) ? $_->textContent : "",
            }} $entry->getElementsByTagName('gs:field')],
        );
        $records->push($record);
    }

    $records;
}

1;


