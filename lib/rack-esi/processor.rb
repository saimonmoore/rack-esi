class Rack::ESI
  class Processor < Struct.new(:esi, :env)

    class Linear < self
      def process_document(d)
        d.xpath('//include').each { |n| process_node n }
      end
    end
    autoload :Threaded, File.expand_path('../threaded', __FILE__)

    NAMESPACE = 'http://www.edge-delivery.org/esi/1.0'
    Error = Class.new RuntimeError

    def read(enumerable, buffer = '')
      enumerable.each { |str| buffer << str }
      buffer
    end

    def include(path)
      # RADAR patron here?
      esi.call env.merge('PATH_INFO' => path, 'REQUEST_URI' => path)
    rescue => e
      return 500, {}, []
    end
    def process_node(node)
      case node.name
      when 'include'
        status, headers, body = include node['src']

        unless status == 200 or node['alt'].nil?
          status, headers, body = include node['alt']
        end

        if status == 200
          node.replace read(body)
          Thread.current[:doc_changed] = true
        elsif node['onerror'] != 'continue'
          raise Error
        end
      else
        node.remove
        Thread.current[:doc_changed] = false
      end
    end
    def process_document(document)
      raise NotImplementedError
    end
    def process(body)
      document = esi.parser.parse read(body), nil, nil, Nokogiri::XML::ParseOptions::DEFAULT_HTML
      process_document document
      [
        Thread.current[:doc_changed] ?
        document.children.map {|c| c.text}.join('') :
        document.send( esi.serializer )
      ]
    end

  end
end
