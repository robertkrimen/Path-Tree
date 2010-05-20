package Path::Tree;
# ABSTRACT: Tree-ish path dispatching

use strict;
use warnings;

use Path::Tree::Rule;
use Path::Tree::Node;
use Path::Tree::Dispatch;

package Path::Tree::DataParser;
# TODO This should be more accurately called 'Data::Mapper'

use Any::Moose;

has rulelist => qw/ is ro lazy_build 1 isa ArrayRef /;
sub _build_rulelist { [] };

has fallback => qw/ is rw isa CodeRef|Path::Tree::DataParser /;

sub parse {
    my $self = shift;
    my $input = shift;

    my $parse = Path::Tree::DataParser::Parse->new( parser => $self, input => $input );

    my @rulelist = @{ $self->rulelist };
    for my $rule (@rulelist) {

        local $_ = $parse->input;

        if ( my $matcher = $rule->matcher ) {
            next unless $matcher->( $parse, $_ );
        }

        my @result = $rule->parser->( $parse, $_ );
        if      ( $parse->success )     {}
        elsif   ( $parse->failure )     {}
        elsif   ( @result && ref $result[0] eq 'Path::Tree::DataParser' )
                                        { $parse = $result[0] }
        elsif   ( @result )             { $parse->result( $result[0] ) }
        else                            { next }

        last;

    }

    unless ( $parse->done ) {
        if ( my $fallback = $self->fallback ) {
            if ( ref $fallback eq 'CODE' ) {
                return $fallback->( $parse, $parse->input );
            }
            else {
                return $fallback->parse( $parse->input );
            }
        }
    }

    return $parse;
}

sub rule {
    my $self = shift;
    my ( $matcher, $parser );
    $matcher = shift if @_ > 1;
    $parser = shift;

    die "Missing parser" unless $parser;
    die "Invalid parser ($parser)" unless ref $parser eq 'CODE';

    my @arguments;
    if ( $matcher ) {
        my $matcher_;
        if      ( ref $matcher eq 'CODE' )      {}
        elsif   ( ref $matcher eq 'Regexp' )    { $matcher_ = sub { $_ =~ $matcher } }
        elsif   ( ref $matcher eq '' &&
                  $matcher =~ m/^(?:CODE|HASH|ARRAY|SCALAR|Regexp)$/x )
                                                { $matcher_ = sub { ref $_ eq $matcher } }
        else                                    { die "Invalid matcher ($matcher)" }
        $matcher_ ||= $matcher;
        push @arguments, matcher => $matcher_;
    }

    my $rule = Path::Tree::DataParser::Rule->new( parser => $parser, @arguments );
    push @{ $self->rulelist }, $rule;
}

package Path::Tree::DataParser::Parse;

use Any::Moose;

has parser => qw/ is ro required 1 isa Path::Tree::DataParser /;
has input => qw/ is ro required 1 /;
has result => qw/ accessor _result predicate success /;
has parse => qw/ is rw predicate recursive /;
has error => qw/ is rw predicate failure /;

sub result {
    my $self = shift;
    return $self->_result( shift ) if @_;
    die "Missing result" unless $self->success;
    return $self->_result;
}

sub parse {
    my $self = shift;
    my $input = shift;
    my $parse = $self->parser->parse( $input );
    $self->parse( $parse );
}

sub done { $_[0]->success || $_[0]->failure }

package Path::Tree::DataParser::Rule;

use Any::Moose;

has matcher => qw/ is ro isa Maybe[CodeRef] /;
has parser => qw/ is ro required 1 isa CodeRef /;

1;
