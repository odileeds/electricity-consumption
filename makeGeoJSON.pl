#!/usr/bin/perl

use Data::Dumper;

%geojson;

$dir = "data/";



# Load House of Commons Library names for English and Welsh MSOAs
%EWmsoas = getCSV($dir."MSOA-Names-1.12.csv",{'id'=>'MSOA11CD','map'=>{'msoa11cd'=>'MSOA11CD','msoa11nm'=>'MSOA11NM','msoa11nmw'=>'MSOA11NMW','msoa11hclnm'=>'MSOA11HCLNM','msoa11hclnmw'=>'MSOA11HCLNMW','Laname'=>'LADNM'}});



# Load in GeoJSON files
# Get English and Welsh MSOA polygons
open(FILE,$dir."Middle_Layer_Super_Output_Areas_(December_2011)_Boundaries_Super_Generalised_Clipped_(BSC)_EW_V3.geojson");
@lines = <FILE>;
foreach $line (@lines){
	# Strip newlines
	$line =~ s/[\n\r]//g;
	# If the line contains an MSOA11CD feature
	if($line =~ /"properties":\{"MSOA11CD":"([^\"]*)"\}/){
		$id = $1;
		$nm = "";
		# Get the HoC name for the MSOA
		if($EWmsoas{$id} && $EWmsoas{$id}{'MSOA11HCLNM'}){
			$nm = $EWmsoas{$id}{'MSOA11HCLNM'};
		}else{
			print "No HoC name for $id\n";
		}
		# Update the properties of the GeoJSON feature
		$line =~ s/\"properties\":\{"MSOA11CD":"([^\"]*)"\}/\"properties\":\{"ID":"$1","Name":"$nm"\}/;
		$geo = $line;
		# Strip trailing commas
		$geo =~ s/,$//g;
		if(!$geojson{$id}){
			# Keep a copy of the GeoJSON feature
			$geojson{$id} = {'geojson'=>$geo,'name'=>$nm};
		}
	}
}
close(FILE);
open(FILE,$dir."Intermediate_Zones_2011-simplified.geojson");
@lines = <FILE>;
foreach $line (@lines){
	# Strip newlines
	$line =~ s/[\n\r]//g;
	# If the line contains an InterZone feature
	if($line =~ s/\"properties\":\{"InterZone":"([^\"]*)","Name":"([^\"]*)"[^\}]*/\"properties\":\{"ID":"$1","Name":"$2"/){
		$id = $1;
		$nm = $2;
		# Switch around the geometry/properties order to be consistent with E&W
		$line =~ s/(,\"geometry\":\{[^\}]*\})(,\"properties\":\{[^\}]*\})/$2$1/;
		$geo = $line;
		$geo =~ s/,$//g;
		if(!$geojson{$id}){
			# Keep a copy of the GeoJSON feature
			$geojson{$id} = {'geojson'=>$geo,'name'=>$nm};
		}
	}
}
close(FILE);



# Load in data
@types = ("domestic","non-domestic");
@props = ("TWh","Median (kWh/meter)");
foreach $typ (@types){
	undef %output;
	foreach $id (sort(keys(%geojson))){
		$output{$id} = $geojson{$id}{'geojson'};
	}

	opendir ( DIR, $dir.$typ."/" ) || die "Error in opening dir $dir$typ\n";
	while(($filename = readdir(DIR))){
		if($filename =~ /([0-9]{4}).csv/){
			print "$dir$typ -  $1\n";
			$yy = $1;
			if($yy > 2000){
				#Local Authority Name,Local Authority Code,MSOA Name,Middle Layer Super Output Area (MSOA) Code, Number of meters , Consumption (kWh) , Mean consumption (kWh per meter) , Median consumption (kWh per meter)
				%data = getCSV($dir.$typ."/".$filename,{'header'=>0,'id'=>'MSOA11CD','map'=>{'Local Authority Code'=>'LADCD','Local Authority Name'=>'LADNM','MSOA Name'=>'MSOA11NM','Middle Layer Super Output Area (MSOA) Code'=>'MSOA11CD',' Number of meters '=>'Meters',' Consumption (kWh) '=>'TWh',' Mean consumption (kWh per meter) '=>'Mean (kWh)',' Median consumption (kWh per meter) '=>'Median (kWh/meter)'}});

				foreach $id (sort(keys(%data))){
					if($output{$id}){
						for($p = 0; $p < @props; $p++){
							$prop = "$yy $props[$p]";
							$v = int($data{$id}{$props[$p]}||0);
							if($props[$p] =~ /TWh/){
								$v = int($v/100000)/10;
							}
							$output{$id} =~ s/(\}\,"geometry")/\,"$prop":$v$1/;
						}
					}else{
						print "WARNING: No polygon for $id\n";
					}
				}
			}
		}
	}

	open(FILE,">utf8","geojson/electricity-consumption-$typ-by-msoa.geojson");
	print FILE "{\n";
	print FILE "\t\"type\":\"FeatureCollection\",\n";
	print FILE "\t\"features\": [\n";
	$i = 0;
	foreach $id (sort(keys(%output))){
		print FILE ($i==0 ? "":",\n")."\t".$output{$id};
		$i++;
	}
	print FILE "\t]\n";
	print FILE "}\n";
	close(FILE);

}






sub getCSV {
	my (@lines,@header,%datum,$c,$i,$id,@data,%dat,$hline);
	my ($file, $props) = @_;

	# Open the file
	open(FILE,$file);
	@lines = <FILE>;
	close(FILE);
	$hline = 0;
	if($props->{'header'}){ $hline = $props->{'header'}; }

	$lines[$hline] =~ s/[\n\r]//g;
	@header = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$lines[$hline]);
	$id = -1;
	for($c = 0; $c < @header; $c++){
		$header[$c] =~ s/(^\"|\"$)//g;	# Remove leading/trailing quotation marks
		if($props->{'map'} && $props->{'map'}{$header[$c]}){
			$header[$c] = $props->{'map'}{$header[$c]};
		}
		if($props->{'id'} && $header[$c] eq $props->{'id'}){
			$id = $c;
		}
	}

	for($i = $hline+1; $i < @lines; $i++){
		undef %datum;
		$lines[$i] =~ s/[\n\r]//g;
		(@cols) = split(/,(?=(?:[^\"]*\"[^\"]*\")*(?![^\"]*\"))/,$lines[$i]);
		for($c = 0; $c < @cols; $c++){
			#print "\t$i = $header[$c] = $cols[$c]\n";
			if($cols[$c] =~ /^" ?([0-9\,]+) ?"$/){
				$cols[$c] =~ s/(^" ?| ?"$)//g;
				$cols[$c] =~ s/\,//g;
			}
			$cols[$c] =~ s/(^\"|\"$)//g;
			if($header[$c] ne ""){
				$datum{$header[$c]} = $cols[$c];
			}
		}
		if($id >= 0){
			$dat{$cols[$id]} = {%datum};
		}else{
			push(@data,{%datum});
		}
	}
	if($id >= 0){
		return %dat;
	}else{
		return @data;
	}
}