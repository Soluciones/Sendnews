# coding: UTF-8

module Sendnews::NewsletterSender

  MAX_SENDGRID_RECIPIENTS = 1000
  MAX_INTENTOS_API_SENDGRID = 10
  ESPERA_ENTRE_INTENTOS_API_SENDGRID = 2

  def crear_y_cronificar_newsletter(destinatarios, asunto, contenido, opciones = {})
    tenemos_engine_suscribir = Object.const_defined?('Suscribir')
    es_una_lista_de_suscripciones = destinatarios.first.respond_to?(:tematica)
    if tenemos_engine_suscribir && es_una_lista_de_suscripciones
      enviar_newsletter_a_suscriptores_tematica(destinatarios.first.tematica, asunto, contenido, opciones)
    else
      enviar_newsletter_a_destinatarios(destinatarios, asunto, contenido, opciones)
    end
  end

  def enviar_newsletter_a_suscriptores_tematica(tematica, asunto, contenido, opciones = {})
    opciones[:sendgrid] ||= SENDGRID_NEWSLETTERS
    nombre_lista = dame_nombre_lista_suscribible(tematica)

    preparar_lista_para_newsletter(nombre_lista, tematica.suscripciones, opciones[:sendgrid]) unless opciones[:sendgrid].get_list(nombre_lista).success?

    enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
  end

  def enviar_newsletter_a_destinatarios(destinatarios, asunto, contenido, opciones = {})
    opciones[:sendgrid] ||= SENDGRID_NEWSLETTERS
    opciones[:nombre_newsletter] ||= genera_nombre_newsletter
    nombre_lista = dame_nombre_lista_newsletter(opciones[:nombre_newsletter])

    preparar_lista_para_newsletter(nombre_lista, destinatarios, opciones[:sendgrid])
    enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
  end

  def enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones = {})
    opciones[:sendgrid] ||= SENDGRID_NEWSLETTERS
    opciones[:identidad] ||= IDENTIDAD_REMITENTE_NEWSLETTERS
    opciones[:nombre_newsletter] ||= genera_nombre_newsletter

    opciones[:sendgrid].add_newsletter(opciones[:nombre_newsletter], identity: opciones[:identidad], subject: asunto, html: contenido)

    MAX_INTENTOS_API_SENDGRID.times do
      respuesta = opciones[:sendgrid].add_recipients(opciones[:nombre_newsletter], nombre_lista)
      break if respuesta['error'].blank?
      sleep ESPERA_ENTRE_INTENTOS_API_SENDGRID
    end

    opciones_envio = opciones[:momento_envio] ? { at: opciones[:momento_envio] } : {}
    opciones[:sendgrid].add_schedule(opciones[:nombre_newsletter], opciones_envio)
  end

private

  def formatear_destinatarios(destinatarios)
    destinatarios.map { |destinatario| { name: destinatario.nombre_apellidos, email: destinatario.email } }
  end

  def genera_nombre_newsletter
    "Newsletter #{I18n.l Time.current.to_date}"
  end

  def dame_nombre_lista_newsletter(nombre_newsletter)
    "Destinatarios #{nombre_newsletter}"
  end

  def dame_nombre_lista_suscribible(suscribible)
    # Esto está duplicado en el engine "suscribir". Debería ser un método Suscribible#nombre_lista.

    "#{suscribible.nombre} (#{suscribible.class.model_name} id: #{suscribible.id})"
  end

  def preparar_lista_para_newsletter(nombre_lista, destinatarios, sendgrid)
    sendgrid.add_list(nombre_lista)

    llenar_lista_destinatarios(nombre_lista, destinatarios, sendgrid)
  end

  def llenar_lista_destinatarios(nombre_lista, destinatarios, sendgrid)
    destinatarios_formateados = formatear_destinatarios(destinatarios)
    destinatarios_formateados.each_slice(MAX_SENDGRID_RECIPIENTS) do |grupo|
      sendgrid.add_emails(nombre_lista, grupo)
    end
  end
end
