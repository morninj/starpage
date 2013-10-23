use strict;
use warnings;
use XML::Simple;
use CAM::PDF;
use Getopt::Long;
use Regexp::Assemble;

# See http://stackoverflow.com/questions/19414763/detect-and-alter-strings-in-pdfs/19551997?noredirect=1#comment29014964_19551997

my ($file, $csv);
my ($c_flag, $w_flag) = (0, 1);
GetOptions('-f=s' => \$file,   '-p=s' => \$csv, 
           '-c!'  => \$c_flag, '-w!'  => \$w_flag) 
    and defined($file)
    and defined($csv)
or die "\nUsage: perl $0 -f FILE -p LIST -c -w\n\n",
       "\t-f\t\tFILE\t PDF file to annotate\n",
       "\t-p\t\tLIST\t comma-separated patterns\n",
       "\t-c or -noc\t\t be case sensitive (default = no)\n",
       "\t-w or -now\t\t whole words only (default = yes)\n";
my $re = Regexp::Assemble->new
    ->add(split(',', $csv))
    ->anchor_word($w_flag)
    ->flags($c_flag ? '' : 'i')
    ->re;
my $xml = qx/mudraw -ttt $file/;
my $tree = XMLin($xml, ForceArray => [qw/page block line span char/]);
my $pdf = CAM::PDF->new($file);

sub __num_nodes_list {
    my $precision = shift;
    [ map {CAM::PDF::Node->new('number', sprintf("%.${precision}f", $_))} @_ ]
}

sub add_highlight {
    my ($idx, $x1, $y1, $x2, $y2) = @_;
    my $p = $pdf->getPage($idx);

    # mirror vertically to get to normal cartesian plane 
    my ($X1, $Y1, $X2, $Y2) = $pdf->getPageDimensions($idx);
    ($x1, $y1, $x2, $y2) = ($X1 + $x1, $Y2 - $y2, $X1 + $x2, $Y2 - $y1);
    # corner radius
    my $r = 2;

    # AP appearance stream
    my $s = "/GS0 gs 1 1 0 rg 1 1 0 RG\n";
    $s .= "1 j @{[sprintf '%.0f', $r * 2]} w\n";
    $s .= "0 0 @{[sprintf '%.1f', $x2 - $x1]} ";
    $s .= "@{[sprintf '%.1f',$y2 - $y1]} re B\n";

    my $highlight = CAM::PDF::Node->new('dictionary', {
        Subtype => CAM::PDF::Node->new('label', 'Highlight'),
        Rect => CAM::PDF::Node->new('array', 
          __num_nodes_list(1, $x1 - $r, $y1 - $r, $x2 + $r * 2, $y2 + $r * 2)),
        QuadPoints => CAM::PDF::Node->new('array', 
            __num_nodes_list(1, $x1, $y2, $x2, $y2, $x1, $y1, $x2, $y1)),
        BS => CAM::PDF::Node->new('dictionary', {
            S => CAM::PDF::Node->new('label', 'S'),
            W => CAM::PDF::Node->new('number', 0),
        }),
        Border => CAM::PDF::Node->new('array', 
            __num_nodes_list(0, 0, 0, 0)),
        C => CAM::PDF::Node->new('array', 
            __num_nodes_list(0, 1, 1, 0)),

        AP => CAM::PDF::Node->new('dictionary', {
            N => CAM::PDF::Node->new('reference', 
                $pdf->appendObject(undef, 
                    CAM::PDF::Node->new('object',
                        CAM::PDF::Node->new('dictionary', {
                            Subtype => CAM::PDF::Node->new('label', 'Form'),
                            BBox => CAM::PDF::Node->new('array',
                              __num_nodes_list(1, -$r, -$r, $x2 - $x1 + $r * 2, 
                                                 $y2 - $y1 + $r * 2)),
                            Resources => CAM::PDF::Node->new('dictionary', {
                                ExtGState => CAM::PDF::Node->new('dictionary', {
                                    GS0 => CAM::PDF::Node->new('dictionary', {
                                        BM => CAM::PDF::Node->new('label', 
                                            'Multiply'),
                                    }),
                                }),
                            }),
                            StreamData => CAM::PDF::Node->new('stream', $s),
                            Length => CAM::PDF::Node->new('number', length $s),
                        }),
                    ),
                ,0),
            ),
        }),
    });

    $p->{Annots} ||= CAM::PDF::Node->new('array', []);
    push @{$pdf->getValue($p->{Annots})}, $highlight;

    $pdf->{changes}->{$p->{Type}->{objnum}} = 1
}

my $page_index = 1;
for my $page (@{$tree->{page}}) {
    for my $block (@{$page->{block}}) {
        for my $line (@{$block->{line}}) {
            for my $span (@{$line->{span}}) {
                my $string = join '', map {$_->{c}} @{$span->{char}};
                while ($string =~ /$re/g) {
                    my ($x1, $y1) = 
                        split ' ', $span->{char}->[$-[0]]->{bbox};
                    my (undef, undef, $x2, $y2) = 
                        split ' ', $span->{char}->[$+[0] - 1]->{bbox};
                    add_highlight($page_index, $x1, $y1, $x2, $y2)
                }
            }
        }
    }
    $page_index ++
}
# $file =~ s/(.{4}$)/++$1/; $pdf->output($file);
$file =~ s/(.{4}$)/-highlighted$1/; $pdf->output($file);

__END__
