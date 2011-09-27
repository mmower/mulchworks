#!/usr/local/bin/ruby -w
#
# This script is intended to smooth an AudioMulch automation curve
#

if ARGV.size < 1
  puts "Specify AMH file to modify"
  exit
end

require 'rubygems'

require 'trollop'
require 'nokogiri'

opts = Trollop::options do
  opt :contraption, "Name of the contraption with automation to be smoothed", :type => String
  opt :property, "Name of the control property whose value(s) is to be smoothed", :type => String
end

Trollop::die "Must specify contraption" unless opts[:contraption]
contraption_name = opts[:contraption]

Trollop::die "Must specify property" unless opts[:property]
property_name = opts[:property]


class Array
  def unzip
    i = 0
    left, right = self.partition do |obj| 
      p = (i&1).zero?
      i += 1
      p
    end
    [left, right]
  end
end


class ModulationSmoother
  def initialize( file_name )
    @file_name = file_name
    @doc       = File.open( file_name ) { |f| Nokogiri::XML( f ) }
  end

  def smooth( contraption_name, property_name )
    if contraption = @doc.at_xpath( "//contraption[@name='#{contraption_name}']" )
      if source = contraption.at_xpath( "//modulation-sources/property-sources[@property-name='#{property_name}']//range-timepoints" )
        source.content = format_points( echo_points( smooth_points( extract_points( source.text ) ) ) )
      else
        puts "No property source found: #{property_name}"
        false
      end
    else
      puts "No contraption found: #{contraption_name}"
      false
    end
  end

  # A no-op tap if we need to print out some diagnostic info
  def echo_points( points )
    puts "POINTS = #{points.size}" if $DEBUG
    puts "FIRST = #{points.first.inspect}" if $DEBUG
    points
  end

  def format_points( points )
    points.map { |tuple| tuple.join( " " ) }.join( "\r" )
  end

  def extract_points( data )
    data.lines.map { |line| line.chomp.split( %r{\s+} ).map { |elem| Float(elem) } }
  end

  def save
    File.open( "#{File.basename( @file_name, ".amh" )}_sm.amh", "w" ) do |file|
      file.write( @doc.to_xml.gsub( "&#13;", "\n" ) )
    end
  end
end


class AveragingSmoother < ModulationSmoother
  
  def smooth_points( points )
    puts "POINTS = #{points.size}" if $DEBUG
    if points.size > 3
      [points.first] + basic_smooth( points[1..-2] ) + [points.last]
    else
      points
    end
  end

  def basic_smooth( points )
    combine_points( points ).map do |p1,p2| 
      time1, min1, max1 = p1
      time2, min2, max2 = p2
      # [(time1+time2)/2,(min1+min2)/2,(max1+max2)/2]
      [time1,(min1+min2)/2,(max1+max2)/2]
    end
  end

  def combine_points( points )
    l,r = points.unzip
    l.zip( r )
  end

end

smoother = AveragingSmoother.new( ARGV.first )
if smoother.smooth( contraption_name, property_name )
  smoother.save
end

