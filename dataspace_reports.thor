require 'json'
require 'nokogiri'
require 'pry-byebug'
require 'typhoeus'

module Dataspace
  class Reports < Thor
    ROOT_COMMUNITY_ID = 267

    no_commands do

      def community_collections_path
        Pathname.new('communities/communities-267-collections.json')
      end

      def community_structure
        content = File.read(community_collections_path)
        JSON.parse(content)
      end

      def base_url
        "https://dataspace.princeton.edu/rest"
      end

      def request_collection_structure(community:, collection:)
        output_file_path = "communities/communities-#{community}-collections-#{collection}.json"
        return if File.exists?(output_file_path)

        request = Typhoeus::Request.new(
          "#{base_url}/collections/#{collection}/items?limit=1000000",
          method: :get
        )
        response = request.run

        File.write(output_file_path, response.body)
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
        content = File.read(file_path)
        doc = Nokogiri::XML(content)
        DublinCoreMetadata.new(doc)
      end

      def build_princeton_metadata(file_path)
        content = File.read(file_path)
        doc = Nokogiri::XML(content)
        PrincetonMetadata.new(doc)
      end

      def cached_collection_index
        file_path = "communities/communities_collections_index.json"
        content = File.read(file_path)
        JSON.parse(content)
      end

      def find_collection(handle:)
        collection_index = cached_collection_index
        collection_structure = collection_index[handle]
        id = collection_structure["id"]
        url = collection_structure["url"]

        file_path = File.expand_path("./output/collections/COLLECTION.#{id}.xml")

        if File.exists?(file_path)
          content = File.read(file_path)
          doc = Nokogiri::XML(content)
        else
          doc = Nokogiri::XML("<collection name='COLLECTION.#{id}' url='#{url}'></collection>")
          File.write(file_path, doc.to_xml)
        end

        doc
      end

      def find_or_create_collection(id:, url:)
        handle = url.gsub('http://arks.princeton.edu/ark:/', '')
        find_collection(handle: handle)
      end

      def write_collection(document)
        elements = document.xpath('collection')
        name = elements.first['name']
        id = name.gsub('COLLECTION.', '')
        file_path = File.expand_path("./output/collections/COLLECTION.#{id}.xml")
        File.write(file_path, document.to_xml)
      end

      def update_collection(dir_path)
        dc_file_path = "#{dir_path}/dublin_core.xml"
        dc_metadata = build_dublin_core_metadata(dc_file_path)

        pu_file_path = "#{dir_path}/metadata_pu.xml"
        pu_metadata = build_princeton_metadata(pu_file_path)

        # Get the collection information from the metadata
        collection_doc = find_or_create_collection(id: nil, url: dc_metadata.url.text)
        item_element = collection_doc.create_element('item')

        dc_file_path = "#{dir_path}/dublin_core.xml"
        dc_metadata = build_dublin_core_metadata(dc_file_path)

        pu_file_path = "#{dir_path}/metadata_pu.xml"
        pu_metadata = build_princeton_metadata(pu_file_path)

        titles = item_element.add_child('<title/>')
        title = titles.first
        title.content = dc_metadata.title.text

        authors = item_element.add_child('<author/>')
        author = authors.first
        author.content = dc_metadata.author.text

        authorids = item_element.add_child('<authorid/>')
        authorid = authorids.first
        authorid.content = pu_metadata.authorid.text

        advisors = item_element.add_child('<advisor/>')
        advisor = advisors.first
        advisor.content = dc_metadata.advisor.text

        classyears = item_element.add_child('<classyear/>')
        classyear = classyears.first
        classyear.content = pu_metadata.classyear.text

        departments = item_element.add_child('<department/>')
        department = departments.first
        department.content = pu_metadata.department.text

        urls = item_element.add_child('<url/>')
        url = urls.first
        url.content = dc_metadata.url.text

        collection_doc.root.add_child(item_element)

        write_collection(collection_doc)
      end

      def find_cached_community(community: nil)
        file_path = "communities/communities-#{community}-collections.json"
        content = File.read(file_path)
        JSON.parse(content)
      end

      def find_cached_collection(community: nil, collection: nil)
        file_path = "communities/communities-#{community}-collections-#{collection}.json"
        content = File.read(file_path)
        JSON.parse(content)
      end

      def build_collection_index(community: nil, collection: nil)
        file_path = "./communities/communities_collections_index.json"
        file_path = File.expand_path(file_path)

        if File.exist?(file_path)
          content = File.read(file_path)
          index = JSON.parse(content)
        else
          File.write(file_path, '{}')
          index = {}
        end

        community_structure = find_cached_community(community: community)
        collection_entry = community_structure.select { |c| c["id"] == collection }.first
        collection_handle = collection_entry["handle"]

        collection_structure = find_cached_collection(community: community, collection: collection)
        collection_structure.each do |item_entry|
          handle = item_entry["handle"]
          index[handle] = { id: collection, url: "http://arks.princeton.edu/ark:/#{handle}" }
        end

        encoded = JSON.generate(index)
        File.write(file_path, encoded)
      end
    end

    desc "cache", "downloads the REST XML for the community and collections"
    def cache
      community_id = ROOT_COMMUNITY_ID
      community_structure.each do |collection_entry|
        collection_id = collection_entry['id']
        request_collection_structure(community: community_id, collection: collection_id)
        build_collection_index(community: community_id, collection: collection_id)
      end
    end

    desc "transform PATH", "transform an exported DataSpace report into a collection report for the Alumni and Donor records department"
    def transform(path)
      directory = Dir.new(path)

      # Iterate through the directories
      directory_path = File.expand_path(directory.path)
      children = Dir.entries(directory_path)
      children = children.reject { |p| p =~ /\.\.?/ }
      children = children.map { |p| File.expand_path("#{directory.path}/#{p}") }
      child_directories = children.select { |c| File.directory?(c) }
      # Dir.glob("#{directory.path}/**/*.xml").each do |file_path|

      child_directories.each_with_index do |dir_path, index|
        # abs_path = File.expand_path("#{directory.path}/#{dir_path}")
        abs_path = dir_path

        puts "Processing #{abs_path}..."
        update_collection(abs_path)
        puts "Finished #{abs_path}...(#{index + 1} of #{child_directories.length})"
      end
    end
  end
end
