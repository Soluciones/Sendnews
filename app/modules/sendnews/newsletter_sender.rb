# coding: UTF-8

module Sendnews::NewsletterSender

  MAX_SENDGRID_RECIPIENTS = 1000
  MAX_INTENTOS_API_SENDGRID = 10
  ESPERA_ENTRE_INTENTOS_API_SENDGRID = 2

  def crear_y_cronificar_newsletter(destinatarios, asunto, contenido, opciones = {})
    tenemos_engine_suscribir = Object.const_defined?('Suscribir')
    es_una_lista_de_suscripciones = destinatarios.first.respond_to?(:suscribible)
    if tenemos_engine_suscribir && es_una_lista_de_suscripciones
      enviar_newsletter_a_suscriptores_suscribible(destinatarios.first.suscribible, asunto, contenido, opciones)
    else
      enviar_newsletter_a_destinatarios(destinatarios, asunto, contenido, opciones)
    end
  end

  def enviar_newsletter_a_suscriptores_suscribible(suscribible, asunto, contenido, opciones = {})
    opciones[:sendgrid] ||= SENDGRID_NEWSLETTERS
    nombre_lista = suscribible.nombre_lista

    lista_existe = !opciones[:sendgrid].get_list(nombre_lista).error?
    unless lista_existe
      preparar_lista_destinatarios(nombre_lista, suscribible.suscripciones_activas, opciones[:sendgrid])
    end

    enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
  end

  def enviar_newsletter_a_destinatarios(destinatarios, asunto, contenido, opciones = {})
    opciones[:sendgrid] ||= SENDGRID_NEWSLETTERS
    opciones[:nombre_newsletter] ||= genera_nombre_newsletter
    nombre_lista = dame_nombre_lista_newsletter(opciones[:nombre_newsletter])

    preparar_lista_destinatarios(nombre_lista, destinatarios, opciones[:sendgrid])
    enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones)
  end

  def enviar_newsletter_a_lista(nombre_lista, asunto, contenido, opciones = {})
    opciones[:sendgrid] ||= SENDGRID_NEWSLETTERS
    opciones[:identidad] ||= IDENTIDAD_REMITENTE_NEWSLETTERS
    opciones[:nombre_newsletter] ||= genera_nombre_newsletter

    respuesta = opciones[:sendgrid].add_newsletter(opciones[:nombre_newsletter],
                                                   identity: opciones[:identidad],
                                                   subject: asunto,
                                                   html: contenido)
    return false if log_sendgrid_error('.add_newsletter', respuesta['error'])

    MAX_INTENTOS_API_SENDGRID.times do
      respuesta = opciones[:sendgrid].add_recipients(opciones[:nombre_newsletter], nombre_lista)
      break if respuesta['error'].blank?
      sleep ESPERA_ENTRE_INTENTOS_API_SENDGRID
    end
    return false if log_sendgrid_error('.add_recipients', respuesta['error'])

    opciones_envio = opciones[:momento_envio] ? { at: opciones[:momento_envio] } : {}
    respuesta = opciones[:sendgrid].add_schedule(opciones[:nombre_newsletter], opciones_envio)
    return false if log_sendgrid_error('.add_schedule', respuesta['error'])

    true
  end

  def preparar_lista_destinatarios(nombre_lista, destinatarios, sendgrid)
    sendgrid.add_list(nombre_lista)

    llenar_lista_destinatarios(nombre_lista, destinatarios, sendgrid)
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

  def llenar_lista_destinatarios(nombre_lista, destinatarios, sendgrid)
    destinatarios_formateados = formatear_destinatarios(destinatarios)
    destinatarios_formateados.each_slice(MAX_SENDGRID_RECIPIENTS) do |grupo|
      llenar_lista_con_grupo(nombre_lista, grupo, sendgrid)
    end
  end

  def llenar_lista_con_grupo(nombre_lista, grupo, sendgrid)
    respuesta = sendgrid.add_emails(nombre_lista, grupo)
    es_un_destinatario_erroneo = (respuesta['error'].present? && grupo.length == 1)

    if es_un_destinatario_erroneo
      Rails.logger.error p "Destinatario erróneo (SendGrid dice: \"#{respuesta['error']}\"):"
      Rails.logger.error p "#{grupo.first.inspect}"
      return
    end

    return if respuesta['error'].blank?

    grupo.each_slice((grupo.length + 1) / 2) do |subgrupo|
      llenar_lista_con_grupo(nombre_lista, subgrupo, sendgrid)
    end
  end

  def log_sendgrid_error(method, sendgrid_error)
    return false if sendgrid_error.blank?

    Rails.logger.error p "Error en #{method} (SendGrid dice: \"#{sendgrid_error}\")"
  end
end
