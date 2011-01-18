package WebService::Google::Spreadsheets::Base;
use strict;
use warnings;
use base qw(Class::Accessor::Fast);

use Carp;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use XML::LibXML;
use UNIVERSAL::isa;
use Exporter::Lite;
use Data::Dumper;

our $VERSION = '0.01';
our @EXPORT = qw(_utf8_off);

__PACKAGE__->mk_accessors(qw(ua message email password));

sub _request {
    my $self = shift;
    my $req  = shift;
    $self->message(undef);

    my $res = $self->ua->request($req);
    if ($res->is_error) {
        warn Dumper $res;
        $self->message($res->content);
        return;
    }
    $res;
}

sub login {
    my $self = shift;
    my $res = $self->_request(
        POST 'https://www.google.com/accounts/ClientLogin', {
            Email       => $self->email,
            Passwd      => $self->password,
            accountType => 'HOSTED_OR_GOOGLE',
            source      => "perl-webservice-google-spreadsheets-$VERSION",
            service     => 'wise',
        }
    ) or return;
    my ($auth) = $res->content =~ /Auth=(.+)/ or return;
    $self->{_authorization} = "GoogleLogin auth=$auth";

    1;
}

sub authorization {
    my $self = shift;
    $self->login unless $self->{_authorization};
    return $self->{_authorization};
}

sub _utf8_off {
    if ($] >= 5.008) {
        require Encode;
        Encode::_utf8_off($_[0]);
    }
}

#<entry xmlns="http://www.w3.org/2005/Atom"
#    xmlns:gs="http://schemas.google.com/spreadsheets/2006">
#  <title type='text'>Table 1</title>
# <summary type='text'>This is a list of all who have registered to vote and
#   whether or not they qualify to vote.</summary>
# <gs:worksheet name='Sheet1' />
# <gs:header row='1' />
# <gs:data numRows='0' startRow='2'>
#   <gs:column index='B' name='Birthday' />
#   <gs:column index='C' name='Age' />
#   <gs:column index='A' name='Name' />
#   <gs:column index='D' name='CanVote' />
# </gs:data>
# </entry>
sub _create_table_xml {
    my ($self, %args) = @_;
    my $worksheet_name  = $args{worksheet_name};
    my $title           = $args{title} || "";
    my $summary         = $args{summary} || "";
    my $header_row      = $args{header_row};
    my $data_start_row  = $args{data_start_row};
    my $data_num_row    = $args{data_num_row} || 0;
    my $data            = $args{data}; # [{index : "B", name : "Birthday"}, {index : "C", name : "Age"}]

    my $dom = XML::LibXML::Document->new();
    my $e_entry = $dom->createElement('entry');
    $e_entry->setAttribute('xmlns' , "http://www.w3.org/2005/Atom");
    $e_entry->setAttribute('xmlns:gs', "http://schemas.google.com/spreadsheets/2006");

    my $e_title = $dom->createElement('title');
    $e_title->setAttribute('type','text');
    $e_title->appendChild($dom->createTextNode($title));
    $e_entry->appendChild($e_title);

    my $e_summary = $dom->createElement('summary');
    $e_summary->setAttribute('type','text');
    $e_summary->appendChild($dom->createTextNode($summary));
    $e_entry->appendChild($e_summary);

    my $e_gs_worksheet = $dom->createElement('gs:worksheet');
    $e_gs_worksheet->setAttribute('name',$worksheet_name);
    $e_entry->appendChild($e_gs_worksheet);

    my $e_gs_header = $dom->createElement('gs:header');
    $e_gs_header->setAttribute('row',$header_row);
    $e_entry->appendChild($e_gs_header);

    my $e_gs_data = $dom->createElement('gs:data');
    $e_gs_data->setAttribute('numRows',$data_num_row);
    $e_gs_data->setAttribute('startRow',$data_start_row);
    foreach my $d (@$data) {
        #   <gs:column index='B' name='Birthday' />
        my $e_gs_column = $dom->createElement('gs:column');
        $e_gs_column->setAttribute('index', $d->{index}); 
        $e_gs_column->setAttribute('name' , $d->{name});
        $e_gs_data->appendChild($e_gs_column); 
    }
    $e_entry->appendChild($e_gs_data);
    return $e_entry;
}

#<entry xmlns="http://www.w3.org/2005/Atom"
#    xmlns:gs="http://schemas.google.com/spreadsheets/2006">
#  <title>Darcy</title>
#  <gs:field name='Birthday'>2/10/1785</gs:field>
#  <gs:field name='Age'>28</gs:field>
#  <gs:field name='Name'>Darcy</gs:field>
#  <gs:field name='CanVote'>No</gs:field>
#</entry>
sub _create_table_record_xml {
    my ($self, %args) = @_;
    my $title           = $args{title} || "";
    my $data            = $args{data}; # [{name : "Birthday", value : "2/10/1785"}, {name : "Age", value: "28"}]

    my $dom = XML::LibXML::Document->new();
    my $e_entry = $dom->createElement('entry');
    $e_entry->setAttribute('xmlns' , "http://www.w3.org/2005/Atom");
    $e_entry->setAttribute('xmlns:gs', "http://schemas.google.com/spreadsheets/2006");

    my $e_title = $dom->createElement('title');
    $e_title->setAttribute('type','text');
    $e_title->appendChild($dom->createTextNode($title));
    $e_entry->appendChild($e_title);

    foreach my $d (@$data) {
        my $e_gs_field = $dom->createElement('gs:field');
        $e_gs_field->setAttribute('name' , $d->{name});
        $e_gs_field->appendChild($dom->createTextNode($d->{value}));
        $e_entry->appendChild($e_gs_field); 
    }
    return $e_entry;
}
1;


