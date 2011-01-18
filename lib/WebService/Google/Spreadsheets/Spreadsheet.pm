package WebService::Google::Spreadsheets::Spreadsheet;
use strict;
use warnings;
use base qw(WebService::Google::Spreadsheets::Base);
use WebService::Google::Spreadsheets::Worksheet;
use WebService::Google::Spreadsheets::Table;

use Carp;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use XML::LibXML;
use UNIVERSAL::isa;
use List::Rubyish;
use Data::Dumper;

__PACKAGE__->mk_accessors(qw(id title key));

sub new {
    my $class = shift;
    $class->SUPER::new({
        @_,
    });
}

sub worksheets {
    my ($self, %args) = @_;
    return $self->{_worksheets} if $self->{_worksheets};
    return $self->{_worksheets} if $self->{_worksheets};
    my $uri = $self->_worksheets_list_uri(%args);

    my $res = $self->_request(
        GET $uri,
        Authorization => $self->authorization,
    ) or return;

    $self->{_worksheets} ||= $self->_parse_worksheets_list_xml($res->content);
}

sub add_worksheet {
    my ($self, %args) = @_;
    # todo
    $self->_clear_cache;
}

sub modify_worksheet {
    my ($self, %args) = @_;
    # todo
    $self->_clear_cache;
}

sub delete_worksheet {
    my ($self, %args) = @_;
    # todo
    $self->_clear_cache;
}

sub get_worksheet_by_title {
    my ($self, $title) = @_;
    $self->worksheets->find(sub{$_->title eq $title}); 
}

sub get_worksheet_by_id {
    my ($self, $worksheet_id) = @_;
    $self->worksheets->find(sub{$_->worksheet_id eq $worksheet_id}); 
}

sub tables {
    my ($self, %args) = @_;
    return $self->{_tables} if $self->{_tables};

    my $uri = $self->_tables_list_uri(%args);

    my $res = $self->_request(
        GET $uri,
        Authorization => $self->authorization,
    ) or return;

    $self->{_tables} ||= $self->_parse_tables_list_xml($res->content);
}

sub get_table_by_title {
    my ($self, $title) = @_;
    $self->tables->find(sub{$_->title eq $title}); 
}

sub get_table_by_number {
    my ($self, $number) = @_;
    $self->tables->find(sub{$_->table_number == $number}); 
}

sub _clear_cache {
    my ($self) = @_;
    $self->{_worksheets} = undef;
    $self->{_tables} = undef;
}

sub _worksheets_list_uri {
    my ($self, %args) = @_;
    my $uri = URI->new(sprintf 'https://spreadsheets.google.com/feeds/worksheets/%s/private/full', $self->key);
    $uri;
}

sub _parse_worksheets_list_xml {
    my ($self, $string) = @_;
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_string($string);
    my $entries = $doc->getElementsByTagName('entry');
    my $worksheets = List::Rubyish->new;
    foreach my $entry (@$entries) {
        my $spreadsheet_id = $entry->getElementsByTagName('id')->[0]->textContent;
        my $worksheet = WebService::Google::Spreadsheets::Worksheet->new(
            email          => $self->email,
            password       => $self->password,
            ua             => $self->ua,
            authorization  => $self->authorization,
            spreadsheet_key => $self->key,
            worksheet_id   => $spreadsheet_id =~ /\/([\d\w]*)$/,
            id             => $entry->getElementsByTagName('id')->[0]->textContent,
            title          => $entry->getElementsByTagName('title')->[0]->textContent,
        );
        $worksheets->push($worksheet);
    }
    $worksheets;
}

sub _tables_list_uri {
    my ($self, %args) = @_;
    my $uri = URI->new(sprintf 'https://spreadsheets.google.com/feeds/%s/tables', $self->key);
    $uri;
}

sub _parse_tables_list_xml {
    my ($self, $string) = @_; 
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_string($string);
    my $entries = $doc->getElementsByTagName('entry');
    my $tables = List::Rubyish->new;
    foreach my $entry (@$entries) {
        my $spreadsheet_id = $entry->getElementsByTagName('id')->[0]->textContent;
        my $table = WebService::Google::Spreadsheets::Table->new(
            ua               => $self->ua,
            authorization    => $self->authorization,
            email            => $self->email,
            password         => $self->password,
            etag           => $entry->getAttribute('gd:etag'),
            id             => $entry->getElementsByTagName('id')->[0]->textContent,
            title          => $entry->getElementsByTagName('title')->[0]->textContent,
            summary        => $entry->getElementsByTagName('summary')->[0]->textContent,
            worksheet_name => $entry->getElementsByTagName('gs:worksheet')->[0]->getAttribute('name'),
            num_rows       => $entry->getElementsByTagName('gs:data')->[0]->getAttribute('numRows'),
            links          => {map {
                    $_->getAttribute('rel') => $_->getAttribute('href')
                } $entry->getElementsByTagName('link')},
            spreadsheet_key => $self->key,
            table_number   => $spreadsheet_id =~ /\/([\d\w]*)$/,
        );
        $tables->push($table);
    }
    $tables;
}


1;
