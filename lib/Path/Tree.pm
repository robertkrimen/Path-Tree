package Path::Tree;
# ABSTRACT: Tree-ish path dispatching

use strict;
use warnings;

use Path::Tree::Rule;
use Path::Tree::Node;
use Path::Tree::Dispatch;

package Path::Tree::DataParser;

use Any::Moose;

has rulelist => qw/ is ro lazy_build 1 isa ArrayRef /;
sub _build_rulelist { [] };

sub parse {
    my $self = shift;
    my $input = shift;

    my $parse = Path::Tree::DataParser::Parse->new( parser => $self, input => $input );

    my @rulelist = @{ $self->rulelist };
    for my $rule (@rulelist) {
        local $_ = $parse->input;
        next unless $rule->matcher->( $parse, $_ );
        my $result = $rule->parser->( $parse, $_ );
        return $parse->parse if $parse->recursive;
        if      ( $parse->success ) {}
        elsif   ( $parse->failure ) {}
        else                        { $parse->result( $result ) }
        last;
    }

    return $parse;
}

sub rule {
    my $self = shift;
    my $matcher = shift;
    my $parser = shift;

    die "Missing matcher" unless $matcher;
    die "Missing parser" unless $parser;
    die "Invalid parser ($parser)" unless ref $parser eq 'CODE';

    my $matcher_;
    if      ( ref $matcher eq 'CODE' )      {}
    elsif   ( ref $matcher eq 'Regexp' )    { $matcher_ = sub { $_ =~ $matcher } }
    elsif   ( ref $matcher eq '' &&
              $matcher =~ m/^(?:CODE|HASH|ARRAY|SCALAR|Regexp)$/x )
                                            { $matcher_ = sub { ref $_ eq $matcher } }
    else                                    { die "Invalid matcher ($matcher)" }
    $matcher_ ||= $matcher;

    my $rule = Path::Tree::DataParser::Rule->new( matcher => $matcher_, parser => $parser );
    push @{ $self->rulelist }, $rule;
}

package Path::Tree::DataParser::Parse;

use Any::Moose;

has parser => qw/ is ro required 1 isa Path::Tree::DataParser /;
has input => qw/ is ro required 1 /;
has result => qw/ accessor _result predicate success /;
sub parsed { shift->success( @_ ) }
has parse => qw/ is rw predicate recursive /;
has error => qw/ is rw predicate failure /;
has pass => qw/ is rw /;

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

package Path::Tree::DataParser::Rule;

use Any::Moose;

has matcher => qw/ is ro required 1 isa CodeRef /;
has parser => qw/ is ro required 1 isa CodeRef /;

1;
