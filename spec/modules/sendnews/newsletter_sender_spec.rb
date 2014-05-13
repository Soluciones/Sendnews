# coding: UTF-8

require "spec_helper"
require "gatling_gun"

class NewsletterSenderIncluder
  include Sendnews::NewsletterSender
end

describe Sendnews::NewsletterSender do

  SENDGRID_NEWSLETTERS = GatlingGun.new('fake_user', 'fake_password')
  IDENTIDAD_REMITENTE_NEWSLETTERS = 'fake_identity'

  subject { NewsletterSenderIncluder.new }

  let(:contenido) { Faker::Lorem.paragraph }
  let(:asunto) { Faker::Lorem.sentence }
  let(:opciones) { { dummy_key: 'dummy value' } }
  let(:suscribible) { FactoryGirl.build(:tematica) }
  let(:nombre_newsletter) { Faker::Lorem.sentence }
  let(:nombre_lista) { Faker::Lorem.sentence }
  let(:destinatarios) { FactoryGirl.build_list(:suscripcion, Random.rand(5..10)) }
  let(:generic_sucessful_response) { { message: 'success' } }
  let(:generic_error_response) { { 'error' => 'error message' } }

  before(:each) do
    # Hacemos stub de todos los métodos para evitar llamadas reales a la API
    GatlingGun.any_instance.stub(add_list: generic_sucessful_response)
    GatlingGun.any_instance.stub(add_emails: generic_sucessful_response)
    GatlingGun.any_instance.stub(add_newsletter: generic_sucessful_response)
    GatlingGun.any_instance.stub(add_recipients: generic_sucessful_response)
    GatlingGun.any_instance.stub(add_schedule: generic_sucessful_response)
    GatlingGun.any_instance.stub(get_list: double('Response', success?: true))

    # Hacemos stub de NewsletterSender::ESPERA_ENTRE_INTENTOS_API_SENDGRID para evitar ralentizar el test
    stub_const('Sendnews::NewsletterSender::ESPERA_ENTRE_INTENTOS_API_SENDGRID', 0)
  end

  shared_examples_for "hace de adaptador hacia #enviar_newsletter_a_destinatarios" do
    it "hace de adaptador hacia #enviar_newsletter_a_destinatarios" do
      subject.should_receive(:enviar_newsletter_a_destinatarios).with(destinatarios, asunto, contenido, opciones)

      subject.crear_y_cronificar_newsletter(destinatarios, asunto, contenido, opciones)
    end
  end

  describe "#crear_y_cronificar_newsletter" do
    context "pasándole como destinatarios una lista de suscripciones a temáticas" do
      let(:destinatarios) { FactoryGirl.build_list(:suscripcion, Random.rand(5..10), suscribible: suscribible) }

      before { Object.stub(:const_defined?).and_call_original }

      context "sin la gema suscribir disponible" do
        before { Object.stub(:const_defined?).with('Suscribir').and_return(false) }

        it_behaves_like "hace de adaptador hacia #enviar_newsletter_a_destinatarios"
      end

      context "con la gema suscribir disponible" do
        before { Object.stub(:const_defined?).with('Suscribir').and_return(true) }

        it "hace de adaptador hacia #enviar_newsletter_a_suscriptores_suscribible" do
          subject.should_receive(:enviar_newsletter_a_suscriptores_suscribible).with(suscribible, asunto, contenido, opciones)

          subject.crear_y_cronificar_newsletter(destinatarios, asunto, contenido, opciones)
        end
      end
    end

    context "pasándole como destinatarios una lista de cosas con email y nombre_apellidos" do
      it_behaves_like "hace de adaptador hacia #enviar_newsletter_a_destinatarios"
    end
  end

  describe "#enviar_newsletter_a_suscriptores_tematica" do
    let(:suscribible) { FactoryGirl.build(:tematica, suscripciones_activas: destinatarios, nombre_lista: nombre_lista) }

    it "hace de adaptador hacia #enviar_newsletter_a_lista" do
      subject.should_receive(:enviar_newsletter_a_lista).with(nombre_lista, asunto, contenido, opciones)

      subject.enviar_newsletter_a_suscriptores_suscribible(suscribible, asunto, contenido, opciones)
    end

    context "cuando la lista de suscriptores al suscribible no existe en SendGrid" do
      before { SENDGRID_NEWSLETTERS.stub(:get_list).with(nombre_lista).and_return(double('Response', success?: false)) }

      it "prepara la lista" do
        subject.should_receive(:preparar_lista_destinatarios)

        subject.enviar_newsletter_a_suscriptores_suscribible(suscribible, asunto, contenido, opciones)
      end
    end

    context "cuando la lista de suscriptores al suscribible ya existe en SendGrid" do
      before { SENDGRID_NEWSLETTERS.stub(:get_list).with(nombre_lista).and_return(double('Response', success?: true)) }

      it "no prepara la lista" do
        subject.should_not_receive(:preparar_lista_destinatarios)

        subject.enviar_newsletter_a_suscriptores_suscribible(suscribible, asunto, contenido, opciones)
      end
    end
  end

  describe "#enviar_newsletter_a_destinatarios" do
    before { subject.should_receive(:dame_nombre_lista_newsletter).and_return(nombre_lista) }  # stub no funciona para métodos privados

    context "si no se le pasa un nombre de newsletter" do
      it "genera uno" do
        subject.should_receive(:genera_nombre_newsletter).and_call_original

        subject.enviar_newsletter_a_destinatarios(destinatarios, asunto, contenido, opciones)
      end
    end

    it "crea una lista en SendGrid" do
      SENDGRID_NEWSLETTERS.should_receive(:add_list).with(nombre_lista)

      subject.enviar_newsletter_a_destinatarios(destinatarios, asunto, contenido, opciones)
    end

    it "llena la lista con destinatarios formateados correctamente" do
      SENDGRID_NEWSLETTERS.should_receive(:add_emails).with(nombre_lista, anything).at_least(:once) do |_, destinatarios_formateados|
        destinatarios_formateados.map{ |d| d[:email] }.should =~ destinatarios.map(&:email)
        destinatarios_formateados.map{ |d| d[:name] }.should =~ destinatarios.map(&:nombre_apellidos)
        generic_sucessful_response
      end

      subject.enviar_newsletter_a_destinatarios(destinatarios, asunto, contenido, opciones)
    end

    it "finalmente llama a #enviar_newsletter_a_lista" do
      subject.should_receive(:enviar_newsletter_a_lista).with(nombre_lista, asunto, contenido, opciones)

      subject.enviar_newsletter_a_destinatarios(destinatarios, asunto, contenido, opciones)
    end
  end

  describe "#enviar_newsletter_a_lista" do
    context "si no se le pasa un nombre de newsletter" do
      it "genera uno" do
        subject.should_receive(:genera_nombre_newsletter).and_call_original

        subject.enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
      end
    end

    it "crea una newsletter con el nombre, contenido, asunto y remitente" do
      subject.should_receive(:genera_nombre_newsletter).and_return(nombre_newsletter) # stub no funciona para métodos privados

      SENDGRID_NEWSLETTERS.should_receive(:add_newsletter)
                          .with(nombre_newsletter,
                                hash_including(identity: IDENTIDAD_REMITENTE_NEWSLETTERS,
                                               subject: asunto,
                                               html: contenido))

      subject.enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
    end

    it "añade la lista como destinatario de la newsletter" do
      subject.should_receive(:genera_nombre_newsletter).and_return(nombre_newsletter) # stub no funciona para métodos privados

      SENDGRID_NEWSLETTERS.should_receive(:add_recipients)
                          .with(nombre_newsletter, nombre_lista)
                          .and_return(generic_sucessful_response)

      subject.enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
    end

    context "si SendGrid no tiene la lista disponible de inmediato" do
      let(:n_intentos_fallidos) { Random.rand(1..(Sendnews::NewsletterSender::MAX_INTENTOS_API_SENDGRID - 1)) }
      let(:respuestas) { ([generic_error_response] * n_intentos_fallidos) + [generic_sucessful_response] }

      before { SENDGRID_NEWSLETTERS.stub(:add_recipients).and_return(*respuestas) }

      it "intenta añadir la lista como destinatario de la newsletter hasta conseguirlo" do
        SENDGRID_NEWSLETTERS.should_receive(:add_recipients).exactly(n_intentos_fallidos + 1).times

        subject.enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
      end

      context "si SendGrid falla continuamente" do
        before { SENDGRID_NEWSLETTERS.stub(:add_recipients).and_return(generic_error_response) }

        it "deja de intentarlo tras #{Sendnews::NewsletterSender::MAX_INTENTOS_API_SENDGRID} intentos" do
          SENDGRID_NEWSLETTERS.should_receive(:add_recipients)
                              .at_most(Sendnews::NewsletterSender::MAX_INTENTOS_API_SENDGRID).times

          subject.enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
        end
      end
    end

    context "pasando en las opciones un momento de envío" do
      let(:opciones) { { momento_envio: 1.day.from_now } }

      it "programa la newsletter para cuando se le ha pedido" do
        subject.should_receive(:genera_nombre_newsletter).and_return(nombre_newsletter) # stub no funciona para métodos privados

        SENDGRID_NEWSLETTERS.should_receive(:add_schedule)
                            .with(nombre_newsletter, hash_including(at: opciones[:momento_envio]))

        subject.enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
      end
    end

    context "sin pasar en las opciones un momento de envío" do
      let(:opciones) { {} }

      it "programa la newsletter para ya" do
        subject.should_receive(:genera_nombre_newsletter).and_return(nombre_newsletter) # stub no funciona para métodos privados

        SENDGRID_NEWSLETTERS.should_receive(:add_schedule).with(nombre_newsletter, {})

        subject.enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
      end
    end
  end

  describe '#preparar_lista_destinatarios' do
    context 'con una lista de 10 destinatarios' do
      let(:destinatarios) { FactoryGirl.build_list(:suscripcion, 10) }

      context 'cuando la llamada a la API devuelve error la primera vez' do
        let(:sendgrid) { double('GatlingGun', add_list: generic_sucessful_response) }

        it 'lo vuelve a intentar partiendo la lista en dos' do
          sendgrid.should_receive(:add_emails).ordered do |_, destinatarios_enviados|
            destinatarios_enviados.should have(10).items
            generic_error_response
          end

          sendgrid.should_receive(:add_emails).twice.ordered do |_, destinatarios_enviados|
            destinatarios_enviados.should have(5).items
            generic_sucessful_response
          end

          subject.preparar_lista_destinatarios('nombre_cualquiera', destinatarios, sendgrid)
        end
      end
    end
  end
end
