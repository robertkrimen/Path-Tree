use Test::t;

use Path::Tree;

my ( $parser, $parse );

$parser = Path::Tree::DataParser->new;
$parser->rule( Regexp => sub { $_ } );

$parse = $parser->parse( qr// );
ok( $parse->success );
is( ref $parse->result, 'Regexp' );

$parse = $parser->parse( 'xyzzy' );
ok( !$parse->parsed );

1;
