use Test::t;

use Path::Tree::DataMap;

my ( $map, $result );

$map = Path::Tree::DataMap->new;
$map->rule( type => 'Regexp', map => sub { $_ } );

$result = $map->map( qr// );
ok( $result );
is( ref $result, 'Regexp' );

$result = $map->map( 'xyzzy' );
ok( ! $result );

$map = Path::Tree::DataMap->new;
$map->rule( type => 'Regexp' => sub { $_ } );

$result = $map->map( qr// );
ok( $result );
is( ref $result, 'Regexp' );

$result = $map->map( 'xyzzy' );
ok( ! $result );

my $i0 = sub { 'a' };
my $i1 = sub { 'b' };

$map = Path::Tree::DataMap->new;
$map->rule( type => 'Regexp', value => $i0 );
$result = $map->map( qr// );
is( $result, $i0 );
is( $map->type_cache->{Regexp}, $i0 );

$map->type_cache->{Regexp} = $i1;
$result = $map->map( qr// );
is( $result, $i1 );

$map->clear_type_cache;
$result = $map->map( qr// );
is( $result, $i0 );
