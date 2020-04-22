
require 'json'
require 'nokogiri'
require 'pry-byebug'
require 'typhoeus'

module Dataspace
  class Reports < Thor
    ROOT_COMMUNITY_ID = 267

    no_commands do
      def dublin_core_file?(file_path)
        file_path =~ /dublin_core\.xml/
      end

      def princeton_metadata_file?(file_path)
        file_path =~ /metadata_pu\.xml/
      end

      class PrincetonMetadataFile < File; end
      class DublinCoreFile < File; end

      def build_export_file(file_path)
        if princeton_metadata_file?(file_path)
          file_class = PrincetonMetadataFile
        elsif dublin_core_file?(file_path)
          file_class = DublinCoreFile
        else
          file_class = File
        end

        file_class.new(file_path)
      end

      def community_collections_path
        Pathname.new('communities/communities-267-collections.json')
      end

      def community_structure
        content = File.read(community_collections_path)
        JSON.parse(content)
      end

      def base_url
        "http://dataspace.princeton.edu/rest"
      end

      def request_collection_structure(community:, collection:)
        request = Typhoeus::Request.new(
          "#{base_url}/communities/#{community}/collections/#{collection}/items",
          method: :get
        )
        response = request.response

        output_file_path = "communities/communities-#{community}-collections-#{collection}.json"
        File.write(output_file_path, 'rb') { |f| f.write(response) }
        response
      end

      class PrincetonMetadata
        def initialize(document)
          @document = document
        end

        def authorid
          @document.xpath('dublin_core/dcvalue[@element="contributor"][@qualifier="authorid"]')
        end

        def classyear
          @document.xpath('dublin_core/dcvalue[@element="date"][@qualifier="classyear"]')

        end

        def department
          @document.xpath('dublin_core/dcvalue[@element="department"][@qualifier="none"]')
        end
      end

      class DublinCoreMetadata
        def initialize(document)
          @document = document
        end

        def title
          @document.xpath('dublin_core/dcvalue[@element="title"][@qualifier="none"]')
        end

        def advisor
          @document.xpath('dublin_core/dcvalue[@element="contributor"][@qualifier="advisor"]')
        end

        def author
          @document.xpath('dublin_core/dcvalue[@element="contributor"][@qualifier="author"]')
        end

        def url
          @document.xpath('dublin_core/dcvalue[@element="identifier"][@qualifier="uri"]')
        end
      end

      def build_dublin_core_metadata(file_path)
        doc = Nokogiri::XML(file_path)
        DublinCoreMetadata.new(doc)
      end

      def build_princeton_metadata(file_path)
        doc = Nokogiri::XML(file_path)
        PrincetonMetadata.new(doc)
      end

      def find_collection(id:, url:)
        binding.pry
      end

      def find_or_create_collection(id:, url:)
        found = find_collection(id:, url:)
        return found unless found.nil?

        Nokogiri::XML("<collection name='COLLECTION.#{id}' url='#{url}'></collection>")
      end

      def build_collection(dir_path)
        collection_doc = Nokogiri::XML('<collection></collection>')

        item_element = collection_doc.create_element('item')

        dc_file_path = "#{dir_path}/dublin_core.xml"
        dc_metadata = build_dublin_core_metadata(dc_file_path)

        pu_file_path = "#{dir_path}/metadata_pu.xml"
        pu_metadata = build_princeton_metadata(pu_file_path)

        item_element.create_element('title', dc_metadata.title)
        item_element.create_element('author', dc_metadata.title)
        item_element.create_element('authorid', pu_metadata.title)
        item_element.create_element('advisor', dc_metadata.title)
        item_element.create_element('classyear', pu_metadata.title)
        item_element.create_element('department', pu_metadata.title)
        item_element.create_element('url', dc_metadata.title)

        write_collection(collection_doc)

        binding.pry
      end

      def append_item(collection, dir_path)
        binding.pry
      end

      def write_collection(collection)
        binding.pry
      end

    end

    desc "cache", "downloads the REST XML for the community and collections"
    def cache
      community_id = ROOT_COMMUNITY_ID
      community_structure.each do |collection_entry|
        collection_id = collection_entry['id']
        request_collection_structure(community: community_id, collection: collection_id)
      end
    end

    desc "transform PATH", "transform an exported DataSpace report into a collection report for the Alumni and Donor records department"
    def transform(path)
      directory = Dir.new(path)

      # Iterate through the directories
      children = Dir.entries(directory_path)
      child_directories = children.select { |c| File.directory?(c) }
      # Dir.glob("#{directory.path}/**/*.xml").each do |file_path|
      child_directories.each do |dir_path|
        collection = build_collection(dir_path)
        append_item(collection, dir_path)
        write_collection(collection)
      end
    end
  end
end
