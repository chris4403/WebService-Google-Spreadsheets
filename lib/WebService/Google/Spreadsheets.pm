package WebService::Google::Spreadsheets;
use strict;
use warnings;
use base qw(WebService::Google::Spreadsheets::Base);

use Carp;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use XML::LibXML;
use UNIVERSAL::isa;
use List::Rubyish;
use Data::Dumper;

use WebService::Google::Spreadsheets::Spreadsheet;
use WebService::Google::Spreadsheets::Worksheet;

__PACKAGE__->mk_accessors(qw());

sub new {
    my $class = shift; 
    $class->SUPER::new({
        ua => LWP::UserAgent->new,
        @_,
    });
}

sub spreadsheets {
    my $self = shift;
    return $self->{_spreadsheets} if $self->{_spreadsheets};
    my $uri = $self->_spreadsheets_list_uri;

    my $res = $self->_request(
        GET $uri,
        Authorization => $self->authorization,
    ) or return;

    $self->{_spreadsheets} ||= $self->_parse_spreadsheets_list_xml($res->content);
}

sub get_spreadsheet_by_key {
    my ($self, $key) = @_;
    $self->spreadsheets->find(sub{$_->key eq $key}); 
}

sub _spreadsheets_list_uri {
    my ($self, %args) = @_;
    my $uri = URI->new('https://spreadsheets.google.com/feeds/spreadsheets/private/full');
    $uri;
}

sub _parse_spreadsheets_list_xml {
    my ($self, $string) = @_;
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_string($string);
    my $entries = $doc->getElementsByTagName('entry');
    my $spreadsheets = List::Rubyish->new;
    foreach my $entry (@$entries) {
        my $id = $entry->getElementsByTagName('id')->[0]->textContent;
        my $spreadsheet = WebService::Google::Spreadsheets::Spreadsheet->new(
            email          => $self->email,
            password       => $self->password,
            ua            => $self->ua,
            authorization => $self->authorization,  
            id            => $entry->getElementsByTagName('id')->[0]->textContent,
            title         => $entry->getElementsByTagName('title')->[0]->textContent,
            key           => $id =~ /\/([\d\w]*)$/,
        );
        $spreadsheets->push($spreadsheet);
    }
    $spreadsheets;
}

1;

__END__

