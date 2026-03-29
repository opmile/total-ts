use warnings;
use CGI qw/:all/;
use DBI;
use JSON;
use LWP::UserAgent;
use MIME::Base64;
use Encode;
use CGI::Cookie;
use Fcntl qw(:flock);
use File::Spec;
use File::Path qw(make_path);
use Number::Format qw(:all);
use HTTP::File;
use File::Basename;
use URI::Escape;
use String::Util 'trim';

require "util.pl";
require "enviar_email.pl";
#----------------------------------------------------
my $logDirectory = '/var/www/logs';
my $logFile = File::Spec->catfile($logDirectory, 'painelContratos.log');

my $tituloPrograma = "<b style='color:#B7872D'>COMERCIAL</b> - Painel de Contratos";
my $arquivo = 'painel_contratos.pl';
my $programa = 'PANCON';
my $versao = 'v.3.0.0';
my $CaminhoDownload = 'http://172.22.220.10/contratos_assinados';
my $CaminhoFisicoDownload = '/var/www/contratos_assinados';

my $query = CGI->new;
my $acao = $query->param('acao') || '';

my %endpoints = (
	'CONSULTAR_DADOS'       => \&consultarDados,
	'CONCLUIR_CONTRATO' 	=> \&concluirContrato,
	'ATIVAR_CONTRATO'       => \&ativarContrato,
	'INATIVAR_CONTRATO'     => \&inativarContrato,
	'CONSULTAR_ANEXOS'      => \&consultarAnexos,
	'GRAVAR_CONTRATO'       => \&gravarContrato,
	'UPLOAD_ANEXO'          => \&uploadAnexo,
	'CONSULTAR_DETALHES'    => \&consultarDetalhes,
	'EDITAR_CONTRATO'       => \&editarContrato,
	'ATUALIZAR_CONTRATO'    => \&atualizarContrato,
);

if ($acao) {
	if (exists $endpoints{$acao}) {
		eval {
			our $dbh = &conectarBD();
		};
		if ($@) {
			print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '500 Internal Server Error');
			my $respostaJson = to_json({ message => "O servidor encontrou um condi��o inesperada que o impediu de atender completamente a requisi��o." });
			my $jsonCodificado = encode('windows-1252', $respostaJson);
			print $jsonCodificado;
			exit;
		}

		our ($user, @Direitos);
		my ($status, $mensagem);
		($user, $status, $mensagem, @Direitos) = &verificaAcessoAPI($programa);

		unless ($user) {
			print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => $status);
			my $respostaJson = to_json({ message => $mensagem });
			my $jsonCodificado = encode('windows-1252', $respostaJson);
			print $jsonCodificado;
			exit;
		}

		if ($acao eq 'ATIVAR_CONTRATO' or $acao eq 'INATIVAR_CONTRATO' or $acao eq 'ATUALIZAR_CONTRATO') {
			if ($Direitos[1] ne 'S'){
				print $query->header(
					-type    => 'application/json',
					-charset => 'windows-1252',
					-status  => '403 Forbidden'
				);
				my $respostaJson = to_json({ message => "Voc� n�o tem permiss�o para executar esta a��o." });
				print encode('utf-8', $respostaJson);
				exit;
			}
		}

		if ($acao eq 'CONCLUIR_CONTRATO') {
			if ($Direitos[2] ne 'S'){
				print $query->header(
					-type    => 'application/json',
					-charset => 'windows-1252',
					-status  => '403 Forbidden'
				);
				my $respostaJson = to_json({ message => "Voc� n�o tem permiss�o para executar esta a��o." });
				print encode('utf-8', $respostaJson);
				exit;
			}
		}

		my $handler = $endpoints{$acao};
		$handler->();

		exit;
	}
	else {
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '404 Not Found');
		my $respostaJson = to_json({ message => "Oops. P�gina n�o encontrada" });
		my $jsonCodificado = encode('windows-1252', $respostaJson);
		print $jsonCodificado;
		exit;
	}
}

require "header.pl";
require "top.pl";
require "menu.pl";
require "footer.pl";

print $header;
print $top;
print $menu;

@Direitos = &verificaAcesso($user, $programa);

if ($Direitos[0] ne 'S') {
	&NaoAutorizado($programa);
	exit;
}

#--------------------------------------------------------------------------------------------------------------
# Sub-rotinas dos Endpoints
#--------------------------------------------------------------------------------------------------------------
sub buscarCityIdLegalOne {
	my ($accessToken, $cidade) = @_;

	return undef unless ($cidade);

	$cidade = trim($cidade);

	my $filtro = "name eq '$cidade'";

	my $url = "$apiResourceUrl/cities?\$filter=$filtro";

	my $userAgent = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
	my $requisicao = HTTP::Request->new(GET => $url);
	$requisicao->header('Authorization' => "Bearer $accessToken");
	$requisicao->header('Content-Type'  => 'application/json');

	my $resposta = $userAgent->request($requisicao);

	if ($resposta->is_success) {
		my $respostaJson = eval { decode_json($resposta->decoded_content) };
		if ($respostaJson && $respostaJson->{value} && scalar @{$respostaJson->{value}} > 0) {
			return $respostaJson->{value}[0]{id};
		}
	} else {
		&logError($logFile, "LegalOne: Falha ao buscar cityId para '$cidade'. Status: " . $resposta->status_line);
	}

	return undef;
}


sub cadastrarContatoLegalOne {
	my ($idCliente) = @_;

	# Busca os dados do cliente na base local
	my $sqlCliente = "
		SELECT nome, responsavel, documento, nacionalidade, estadoCivil,
			   profissao, dataNascimento, sexo, telefone, email,
			   endereco, bairro, cidade, estado, cep, categoria
		FROM clientes
		WHERE idCliente = ?
	";
	my $sthCliente = $dbh->prepare($sqlCliente);
	$sthCliente->execute($idCliente);
	my ($nome, $responsavel, $documento, $nacionalidade, $estadoCivil,
		$profissao, $dataNascimento, $sexo, $telefone, $email,
		$endereco, $bairro, $cidade, $estado, $cep, $categoria) = $sthCliente->fetchrow_array();

	unless ($documento) {
		&logError($logFile, "LegalOne: Cliente $idCliente sem documento cadastrado. Cadastro no LegalOne ignorado.");
		return (undef, "Cliente sem documento cadastrado.");
	}

	# Remove formatacao do documento (pontos, tracos, barras)
	my $documentoLimpo = $documento;
	$documentoLimpo =~ s/[.\-\/]//g;

	# Obtem o token de acesso
	my ($accessToken) = &AccessTokenLegalOne();
	unless ($accessToken) {
		&logError($logFile, "LegalOne: Falha ao obter token de acesso para cadastro do cliente $idCliente.");
		return (undef, "Falha ao obter token de acesso do LegalOne.");
	}

	# Mapeamento de categoria do banco para listItemIdValue do LegalOne
	# 1=Normal, 2=Bronze, 3=Prata, 4=Ouro, 5=Estrategico
	my %categoriaCompany = (1 => 44, 2 => 42, 3 => 41, 4 => 40, 5 => 39);
	my %categoriaIndividual = (1 => 43, 2 => 38, 3 => 37, 4 => 36, 5 => 35);

	$categoria ||= 1; # Default: Normal

	# Busca o cityId no LegalOne a partir da cidade do cliente
	my $cityId = &buscarCityIdLegalOne($accessToken, $cidade);
	if (!$cityId && $cidade) {
		&logError($logFile, "LegalOne: Nao foi possivel encontrar cityId para '$cidade' do cliente $idCliente");
	}

	my $apiUrl;
	my $payload;

	if (length($documentoLimpo) == 14) {
		# CNPJ -> Cadastrar como Company
		$apiUrl = "$apiResourceUrl/companies";

		my $listItemId = $categoriaCompany{$categoria} || $categoriaCompany{1};

		$payload = {
			name                 => $nome,
			identificationNumber => $documento,
			notes                => $responsavel ? "Responsavel: $responsavel" : undef,
			customFields         => [{
				customFieldId   => 3792,
				listItemIdValue => $listItemId,
			}],
		};

		# Adiciona email se disponivel
		if ($email) {
			$payload->{emails} = [{
				email             => $email,
				typeId            => 1,
				isMainEmail       => JSON::true,
				isBillingEmail    => JSON::true,
				isInvoicingEmail  => JSON::true,
			}];
		}

		# Adiciona telefone se disponivel
		if ($telefone) {
			$payload->{phones} = [{
				number      => $telefone,
				typeId      => 3,
				isMainPhone => JSON::true,
			}];
		}

		# Adiciona endereco se disponivel
		if ($endereco) {
			my $enderecoObj = {
				type                => "Comercial",
				addressLine1        => $endereco,
				neighborhood        => $bairro,
				areaCode            => $cep,
				isMainAddress       => JSON::true,
				isBillingAddress    => JSON::true,
				isInvoicingAddress  => JSON::true,
			};
			$enderecoObj->{cityId} = $cityId if $cityId;
			$payload->{addresses} = [$enderecoObj];
		}

	} elsif (length($documentoLimpo) == 11) {
		# CPF -> Cadastrar como Individual
		$apiUrl = "$apiResourceUrl/individuals";

		my $listItemId = $categoriaIndividual{$categoria} || $categoriaIndividual{1};

		$payload = {
			name                 => $nome,
			identificationNumber => $documento,
			nacionality          => $nacionalidade,
			customFields         => [{
				customFieldId   => 3791,
				listItemIdValue => $listItemId,
			}],
		};

		# Mapeia sexo do banco (M/F) para o enum da API (Male/Female)
		if ($sexo) {
			if (uc($sexo) eq 'M') {
				$payload->{gender} = 'Male';
			} elsif (uc($sexo) eq 'F') {
				$payload->{gender} = 'Female';
			}
		}

		# Formata data de nascimento para ISO 8601 (yyyy-mm-ddT00:00:00)
		if ($dataNascimento) {
			$payload->{birthDate} = "${dataNascimento}T00:00:00";
		}

		# Monta as notas com informacoes adicionais
		my @notasExtra;
		push @notasExtra, "Responsavel: $responsavel"     if $responsavel;
		push @notasExtra, "Estado Civil: $estadoCivil"     if $estadoCivil;
		push @notasExtra, "Profissao: $profissao"          if $profissao;
		$payload->{notes} = join(" | ", @notasExtra) if @notasExtra;

		# Adiciona email se disponivel
		if ($email) {
			$payload->{emails} = [{
				email             => $email,
				typeId            => 1,
				isMainEmail       => JSON::true,
				isBillingEmail    => JSON::true,
				isInvoicingEmail  => JSON::true,
			}];
		}

		# Adiciona telefone se disponivel
		if ($telefone) {
			$payload->{phones} = [{
				number      => $telefone,
				typeId      => 3,
				isMainPhone => JSON::true,
			}];
		}

		# Adiciona endereco se disponivel
		if ($endereco) {
			my $enderecoObj = {
				type                => "Residential",
				addressLine1        => $endereco,
				neighborhood        => $bairro,
				areaCode            => $cep,
				isMainAddress       => JSON::true,
				isBillingAddress    => JSON::true,
				isInvoicingAddress  => JSON::true,
			};
			$enderecoObj->{cityId} = $cityId if $cityId;
			$payload->{addresses} = [$enderecoObj];
		}

	} else {
		&logError($logFile, "LegalOne: Documento do cliente $idCliente possui tamanho invalido ($documento). Cadastro ignorado.");
		return (undef, "Documento com formato invalido (nem CPF nem CNPJ).");
	}

	# Remove chaves com valor undef do payload
	foreach my $key (keys %$payload) {
		delete $payload->{$key} unless defined $payload->{$key};
	}

	# Realiza o POST na API do LegalOne
	my $jsonPayload = encode_json($payload);

	my $userAgent = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
	my $requisicao = HTTP::Request->new(POST => $apiUrl);
	$requisicao->header('Authorization' => "Bearer $accessToken");
	$requisicao->header('Content-Type'  => 'application/json');
	$requisicao->content($jsonPayload);

	my $resposta = $userAgent->request($requisicao);

	if ($resposta->is_success) {
		my $respostaJson = eval { decode_json($resposta->decoded_content) };
		my $idLegalOne = $respostaJson->{id} || 'N/D';
		&logError($logFile, "LegalOne: Contato cadastrado com sucesso. Cliente=$idCliente, ID_LegalOne=$idLegalOne, Tipo=" . (length($documentoLimpo) == 14 ? 'Company' : 'Individual'));
		return ($idLegalOne, undef);
	} else {
		my $erroDetalhado = "Status: " . $resposta->status_line . " | Resposta: " . $resposta->decoded_content;
		&logError($logFile, "LegalOne: Falha ao cadastrar contato do cliente $idCliente. $erroDetalhado");
		return (undef, "Falha ao cadastrar contato no LegalOne: " . $resposta->status_line);
	}
}

sub dispararEmailFinanceiro {
	my ($idContrato, $caminhoAnexoContrato, $caminhoAnexoComprovante) = @_;

	my $sqlDados = "
		SELECT
			c.nome,
			p.tipoContrato,
			p.valorTotal,
			p.valorInvestimento,
			p.obsGeral
		FROM dadosContrato p
		LEFT JOIN clientes c ON c.idCliente = p.idCliente
		WHERE p.idContrato = ?
	";
	my $sthDados = $dbh->prepare($sqlDados);
	$sthDados->execute($idContrato);
	my ($nomeCliente, $tipoContrato, $valorTotal, $valorInvestimento, $obsGeral) = $sthDados->fetchrow_array();

	$nomeCliente  ||= 'N/D';
	$tipoContrato ||= 'N/D';
	$valorInvestimento   ||= '';
	$obsGeral     ||= '';

	my $frm = Number::Format->new(
		-thousands_sep => '.', -decimal_point => ',',
		-decimal_digits => 2,  -decimal_fill   => 1
	);
	my $valorTotalFormatado = $frm->format_number($valorTotal || 0);

	my $destinatario = 'financeiro@joaodomingosadv.com';

	# E-mail do contrato assinado
	if ($caminhoAnexoContrato) {
		my $assunto = "Contrato Assinado: $nomeCliente - ID: $idContrato";
		my $corpo = qq{
			Ol�,<br><br>
			O contrato do cliente <strong>$nomeCliente</strong> foi assinado e est� em anexo.<br><br>
			Abaixo, um resumo das informa��es principais:<br>
			<ul style="list-style-type: none; padding: 0;">
				<li><strong>Cliente:</strong> $nomeCliente</li>
				<li><strong>ID do Contrato:</strong> $idContrato</li>
				<li><strong>Tipo de Contrato:</strong> $tipoContrato</li>
				<li><strong>Valor Total do Contrato:</strong> R\$ $valorTotalFormatado</li>
			</ul>
			<hr>
			<h4><strong>Valor do �xito:</strong></h4>
			<div style="background-color:#f5f5f5; border:1px solid #ccc; padding:15px; border-radius: 4px; font-family: courier, monospace;">
				$valorInvestimento
			</div>
			<h4><strong>Observa��es Gerais:</strong></h4>
			<div style="background-color:#f5f5f5; border:1px solid #ccc; padding:15px; border-radius: 4px; font-family: courier, monospace;">
				$obsGeral
			</div>
			<br>
			<i>Este � um e-mail autom�tico, por favor n�o responda.</i>
		};

		enviarEmail(
			$idContrato,
			'PANCON',
			$destinatario,
			$assunto,
			$corpo,
			$caminhoAnexoContrato
		);
	}

	# E-mail do comprovante de pagamento
	if ($caminhoAnexoComprovante) {
		my $assunto = "Comprovante de Pagamento Enviado: $nomeCliente - ID: $idContrato";
		my $corpo = qq{
			Ol�,<br><br>
			O comprovante de pagamento do cliente <strong>$nomeCliente</strong> foi enviado e est� em anexo.<br><br>
			Abaixo, um resumo das informa��es principais:<br>
			<ul style="list-style-type: none; padding: 0;">
				<li><strong>Cliente:</strong> $nomeCliente</li>
				<li><strong>ID do Contrato:</strong> $idContrato</li>
				<li><strong>Tipo de Contrato:</strong> $tipoContrato</li>
				<li><strong>Valor Total do Contrato:</strong> R\$ $valorTotalFormatado</li>
			</ul>
			<br>
			<i>Este � um e-mail autom�tico, por favor n�o responda.</i>
		};

		enviarEmail(
			$idContrato,
			'PANCON',
			$destinatario,
			$assunto,
			$corpo,
			$caminhoAnexoComprovante
		);
	}
}

sub consultarDados {
	my $frm_number = Number::Format->new(
		-thousands_sep     => '.', -decimal_point     => ',',
		-int_curr_symbol   => 'R$ ', -mon_thousands_sep => ',',
		-mon_decimal_point => '.',   -decimal_digits    => 2,
		-decimal_fill      => 1
	);

	my $draw = $query->param('draw') || 0;
	my $start = $query->param('start') || 0;
	my $length = $query->param('length') || 30;

	# Par�metros de filtro do formul�rio
	my $idContrato    = $query->param('idContrato');
	my $tipoContrato  = $query->param('tipoContrato');
	my $dataInicial   = $query->param('dataInicial');
	my $dataFinal     = $query->param('dataFinal');
	my $idCliente     = $query->param('idCliente');
	my $statusContrato = $query->param('statusContrato');

	my @params;
	my $where = " WHERE 1 = 1 ";

	if ($idContrato) {
		$where .= " AND p.idContrato = ? ";
		push @params, $idContrato;
	}
	if ($idCliente) {
		$where .= " AND p.idCliente = ? ";
		push @params, $idCliente;
	}
	if ($tipoContrato) {
		$where .= " AND FIND_IN_SET(?, REPLACE(p.tipoContrato, ', ', ',')) > 0 ";
		push @params, $tipoContrato;
	}
	if ($dataInicial && $dataFinal) {
		my ($dI, $mI, $aI) = split('/', $dataInicial);
		my ($dF, $mF, $aF) = split('/', $dataFinal);
		$where .= " AND p.dataInclusao BETWEEN ? AND ? ";
		push @params, "$aI-$mI-$dI 00:00:00", "$aF-$mF-$dF 23:59:59";
	}
	if ($statusContrato) {
		$where .= " AND p.statusContrato = ? ";
		push @params, $statusContrato;
	}

	eval {
		# 1. Contagem total de registros filtrados
		my $sql_count = "SELECT COUNT(p.idContrato) FROM dadosContrato p $where";
		my $sth_count = $dbh->prepare($sql_count);
		$sth_count->execute(@params);
		our ($recordsFiltered) = $sth_count->fetchrow_array();

		# 2. Contagem total de registros (sem filtro)
		my $sql_total = "SELECT COUNT(idContrato) FROM dadosContrato";
		my $sth_total = $dbh->prepare($sql_total);
		$sth_total->execute();
		our ($recordsTotal) = $sth_total->fetchrow_array();

		my $sql = "
			SELECT
				p.idContrato,
				p.statusContrato,
				DATE_FORMAT(p.dataInclusao, '%d/%m/%Y'),
				p.tipoContrato,
				c.nome,
				p.valorTotal,
				p.anexoContratoAssinado,
				p.comprovantePagamento,
				DATE_FORMAT(p.dataAnexoContrato, '%d/%m/%Y %H:%i:%s'),
				DATE_FORMAT(p.dataConclusaoContrato, '%d/%m/%Y %H:%i:%s')
			FROM dadosContrato p
			LEFT JOIN clientes c ON c.idCliente = p.idCliente
			$where
			ORDER BY p.idContrato DESC
			LIMIT ? OFFSET ?
		";

		push @params, $length, $start;
		my $sth = $dbh->prepare($sql);
		$sth->execute(@params);

		our @data;
		while (my @row = $sth->fetchrow_array()) {
			$row[5] = $frm_number->format_number($row[5] || 0);

			push @data, \@row;
		}
	};

	if ($@) {
		&logError($logFile, "Erro interno ao consultar dados: $@");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '500 Internal Server Error');
		my $respostaJson = to_json({ message => "O servidor encontrou um condi��o inesperada que o impediu de atender completamente a requisi��o." });
		my $jsonCodificado = encode('windows-1252', $respostaJson);
		print $jsonCodificado;
		exit;
	}

	my $json_response = {
		"draw"            => int($draw),
		"recordsTotal"    => int($recordsTotal),
		"recordsFiltered" => int($recordsFiltered),
		"data"            => \@data,
	};

	print $query->header(-type => 'application/json', -charset => 'windows-1252');
	print to_json($json_response);
}

sub consultarAnexos {
	my $idContrato = $query->param('id');

	unless ($idContrato && $idContrato =~ /^\d+$/) {
		&logError($logFile, "ID do contrato inv�lido ou n�o fornecido: $@");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
		my $respostaJson = to_json({ message => "Dados incompletos. Verifique se todos os campos foram preenchidos." });
		my $jsonCodificado = encode('windows-1252', $respostaJson);
		print $jsonCodificado;
		exit;
	}

	my ($anexoContrato, $comprovantePag, $dataAnexoContratoF);
	eval {
		my $sql = "SELECT anexoContratoAssinado, comprovantePagamento, DATE_FORMAT(dataAnexoContrato, '%d/%m/%Y %H:%i:%s') FROM dadosContrato WHERE idContrato = ?";
		my $sth = $dbh->prepare($sql);
		$sth->execute($idContrato);
		($anexoContrato, $comprovantePag, $dataAnexoContratoF) = $sth->fetchrow_array();
	};
	if ($@) {
		&logError($logFile, "Erro interno ao consultar anexos: $@");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '500 Internal Server Error');
		my $respostaJson = to_json({ message => "O servidor encontrou um condi��o inesperada que o impediu de atender completamente a requisi��o." });
		my $jsonCodificado = encode('windows-1252', $respostaJson);
		print $jsonCodificado;
		exit;
	}

	my $criarTituloSecao = sub {
		my ($titulo) = @_;
		return qq|<div class="form-group" style="background-color: #212121; padding: 15px; border-radius: 6px; margin-bottom: 5px; color:#FFFFFF; font-weight: bold;">$titulo</div>|;
	};

	my $abrirBoxConteudo = sub {
		return qq|<div class="form-group" style="background-color: #212121; padding: 15px; border-radius: 6px; margin-bottom: 20px;">|;
	};

	my $fecharBoxConteudo = sub {
		return qq|</div>|;
	};

	my $criarLinhaArquivo = sub {
		my ($name, $label) = @_;
		return << "HTML";
<div class="row" style="margin-bottom: 10px;">
	<div class="col-sm-3 label-responsiva">$label:</div>
	<div class="col-sm-9">
		<label for="$name" class="file-upload-label btn btn-sm" style="background-color: #303030; color: white; border: 1px solid #444; cursor: pointer;">
			<i class="fa fa-cloud-upload" style="margin-right: 8px;"></i>Selecione o arquivo
		</label>
		<input type="file" id="$name" name="$name" style="display: none;" onchange="updateFileName(this)">
		<div class="file-name-display" style="font-size: 0.9em; color: #aaa; font-weight: bold; padding-left: 2px; margin-top: 5px;">
			Nenhum arquivo selecionado
		</div>
	</div>
</div>
HTML
	};

	my $criarLinhaDetalhe = sub {
		my ($label, $valor) = @_;
		$valor = $valor || '-';
		return << "HTML";
<div class="row" style="margin-bottom: 5px;">
	<div class="col-sm-3 label-responsiva">$label:</div>
	<div class="col-sm-9" style="color: #FFFFFF;">$valor</div>
</div>
HTML
	};

	# --- Monta o HTML ---
	my $htmlConteudo = qq|<form id="formUploadAnexos" class="form-horizontal" enctype="multipart/form-data">|;
	$htmlConteudo .= qq|<input type="hidden" id="idContratoAnexo" name="idContratoAnexo" value="$idContrato">|;

	# === SE��O 1: ENVIAR ARQUIVOS ===
	$htmlConteudo .= $criarTituloSecao->("1 - ENVIAR ARQUIVOS");
	$htmlConteudo .= $abrirBoxConteudo->();
	$htmlConteudo .= $criarLinhaArquivo->('uploadContratoAssinado', 'Contrato Assinado');
	$htmlConteudo .= $criarLinhaArquivo->('uploadComprovantePagamento', 'Comprovante de Pagamento');
	$htmlConteudo .= $fecharBoxConteudo->();

	$htmlConteudo .= '</form>';

	# === SE��O 2: ARQUIVOS DO CONTRATO ===
	$htmlConteudo .= $criarTituloSecao->("2 - ARQUIVOS DO CONTRATO");
	$htmlConteudo .= $abrirBoxConteudo->();

	if ($anexoContrato) {
		my $linkContrato = qq|<a href="$CaminhoDownload/$anexoContrato" target="_blank" class="btn btn-md btn-outline-light" title="$anexoContrato" style="padding:0; white-space: normal; word-break: break-all; text-align: left;"><i class="fa fa-file-alt"></i> $anexoContrato</a>|;
		$htmlConteudo .= $criarLinhaDetalhe->("Contrato Assinado", $linkContrato);
	} else {
		$htmlConteudo .= $criarLinhaDetalhe->("Contrato Assinado", "Nenhum arquivo enviado");
	}

	$htmlConteudo .= $criarLinhaDetalhe->("Data Anexo Contrato", $dataAnexoContratoF);

	if ($comprovantePag) {
		my $linkComprovante = qq|<a href="$CaminhoDownload/$comprovantePag" target="_blank" class="btn btn-md btn-outline-light" title="$comprovantePag" style="padding: 0; white-space: normal; word-break: break-all; text-align: left;"><i class="fa fa-file-alt"></i> $comprovantePag</a>|;
		$htmlConteudo .= $criarLinhaDetalhe->("Comprovante de Pagamento", $linkComprovante);
	} else {
		$htmlConteudo .= $criarLinhaDetalhe->("Comprovante de Pagamento", "Nenhum arquivo enviado");
	}

	$htmlConteudo .= $fecharBoxConteudo->();

	print $query->header(-type => 'text/html', -charset => 'windows-1252');
	print encode('UTF-8', $htmlConteudo);
}

sub ativarContrato {
	return alterarStatusContrato(1);
}

sub concluirContrato {
	return alterarStatusContrato(8);
}

sub inativarContrato {
	return alterarStatusContrato(9);
}

sub alterarStatusContrato {
	my ($novoStatus) = @_;

	my $idContrato = $query->param('idContrato');
	my $json_response;

	unless ($idContrato && $idContrato =~ /^\d+$/) {
		&logError($logFile, "ID do contrato inv�lido ou n�o fornecido");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
		my $respostaJson = to_json({ message => "Dados incompletos. Verifique se todos os campos foram preenchidos." });
		my $jsonCodificado = encode('windows-1252', $respostaJson);
		print $jsonCodificado;
		exit;
	}

	eval {
		my $sql;
		my @params;

		if ($novoStatus == 8) {
			$sql = "UPDATE dadosContrato SET statusContrato = ?, dataConclusaoContrato = NOW() WHERE idContrato = ?";
			@params = ($novoStatus, $idContrato);
		} else {
			$sql = "UPDATE dadosContrato SET statusContrato = ? WHERE idContrato = ?";
			@params = ($novoStatus, $idContrato);
		}

		my $sth = $dbh->prepare($sql);
		$sth->execute(@params);

		$json_response = { success => 1 };
	};
	if ($@) {
		&logError($logFile, "Erro interno ao alterar status do contrato: $@");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '500 Internal Server Error');
		my $respostaJson = to_json({ success => 0, message => "O servidor encontrou um condi��o inesperada que o impediu de atender completamente a requisi��o." });
		my $jsonCodificado = encode('windows-1252', $respostaJson);
		print $jsonCodificado;
		exit;
	}

	print $query->header(-type => 'application/json', -charset => 'windows-1252');
	print to_json($json_response);
}

sub gravarContrato {
	my $json_response;

	# Captura dos campos do formulario linhaCadastro
	my $cliente            = $query->param('cliente');
	my $tipoContrato       = $query->param('tipoContrato');
	my $idContratoAditivo  = $query->param('idContratoAditivo');
	my $valorTotal         = $query->param('valorTotal');
	my $vencimento         = $query->param('vencimento');
	my $entradaInicial     = $query->param('entradaInicial');
	my $entradaRestante    = $query->param('entradaRestante');
	my $qtdParcelasEntrada = $query->param('qtdParcelasEntrada');
	my $valorCaso          = $query->param('valorCaso');
	my $qtdParcelasCaso    = $query->param('qtdParcelasCaso');
	my $valorExito         = $query->param('valorExito');
	my $observacoes        = $query->param('observacoes');

	my @erros;

	push @erros, "O campo 'Cliente' � obrigat�rio"          unless $cliente;
	push @erros, "O campo 'Tipo Contrato' � obrigat�rio"    unless $tipoContrato;
	push @erros, "O campo 'Valor Total' � obrigat�rio"      unless $valorTotal;
	push @erros, "O campo 'Vencimento' � obrigat�rio"       unless $vencimento;
	push @erros, "O campo 'Entrada Inicial' � obrigat�rio"  unless $entradaInicial;
	push @erros, "O campo 'Entrada Restante' � obrigat�rio" unless $entradaRestante;
	push @erros, "O campo 'Valor Caso' � obrigat�rio"       unless $valorCaso;
	push @erros, "O campo 'Valor do �xito' � obrigat�rio"  unless $valorExito;
	push @erros, "O campo 'Observa��es gerais' � obrigat�rio" unless $observacoes;

	# Se tipo ADITIVO, exige o ID do contrato principal
	if ($tipoContrato && $tipoContrato =~ /ADITIVO/) {
		unless ($idContratoAditivo && $idContratoAditivo =~ /^\d+$/) {
			push @erros, "O campo 'ID Contrato Principal' � obrigat�rio para contratos do tipo ADITIVO.";
		}
	}

	# Valida formato de data dd/mm/yyyy
	if ($vencimento && $vencimento !~ m|^\d{2}/\d{2}/\d{4}$|) {
		push @erros, "O campo 'Vencimento' deve estar no formato dd/mm/aaaa.";
	}


	if ($cliente && $cliente !~ /^\d+$/) {
		push @erros, "Cliente inv�lido.";
	}

	# Valida parcelas
	if (defined $qtdParcelasEntrada && $qtdParcelasEntrada ne '' && $qtdParcelasEntrada !~ /^\d+$/) {
		push @erros, "O campo 'Parcelas entrada' deve ser um n�mero inteiro.";
	}
	if (defined $qtdParcelasCaso && $qtdParcelasCaso ne '' && $qtdParcelasCaso !~ /^\d+$/) {
		push @erros, "O campo 'Parcelas caso' deve ser um n�mero inteiro.";
	}

	if (scalar @erros > 0) {
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
		my $respostaJson = to_json({ success => 0, message => join(" ", @erros) });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	my $converterMoeda = sub {
		my ($valor) = @_;
		return 0 unless $valor;
		$valor =~ s/\.//g;
		$valor =~ s/,/./;
		return $valor;
	};

	$valorTotal      = $converterMoeda->($valorTotal);
	$entradaInicial  = $converterMoeda->($entradaInicial);
	$entradaRestante = $converterMoeda->($entradaRestante);
	$valorCaso       = $converterMoeda->($valorCaso);

	# Validacao regra de negocio: valorTotal = entradaInicial + entradaRestante + valorCaso
	{
		my $somaEsperada = sprintf("%.2f", $entradaInicial + $entradaRestante + $valorCaso);
		my $valorTotalFmt = sprintf("%.2f", $valorTotal);
		if ($valorTotalFmt ne $somaEsperada) {
			print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
			my $respostaJson = to_json({ success => 0, message => "O Valor Total (R\$ $valorTotalFmt) deve ser igual a soma da Entrada Inicial + Entrada Restante + Valor Caso (R\$ $somaEsperada)." });
			print encode('windows-1252', $respostaJson);
			exit;
		}
	}

	# Convers�o da data de vencimento (dd/mm/yyyy -> yyyy-mm-dd)
	my $vencimentoDB = undef;
	if ($vencimento =~ m|^(\d{2})/(\d{2})/(\d{4})$|) {
		$vencimentoDB = "$3-$2-$1";
	}

	# Validacao se o cliente existe na base
	my ($existeCliente);
	eval {
		my $sql = "SELECT idCliente FROM clientes WHERE idCliente = ?";
		my $sth = $dbh->prepare($sql);
		$sth->execute($cliente);
		($existeCliente) = $sth->fetchrow_array();
	};
	unless ($existeCliente) {
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
		my $respostaJson = to_json({ success => 0, message => "Cliente n�o encontrado na base de dados." });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	# Se for ADITIVO, validar se o contrato principal existe
	if ($tipoContrato =~ /ADITIVO/ && $idContratoAditivo) {
		my ($existeContrato);
		eval {
			my $sql = "SELECT idContrato FROM dadosContrato WHERE idContrato = ?";
			my $sth = $dbh->prepare($sql);
			$sth->execute($idContratoAditivo);
			($existeContrato) = $sth->fetchrow_array();
		};
		unless ($existeContrato) {
			print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
			my $respostaJson = to_json({ success => 0, message => "O contrato principal (ID $idContratoAditivo) n�o foi encontrado." });
			print encode('windows-1252', $respostaJson);
			exit;
		}
	}

	# -------------------------------------------------------------------------
	# INSERT no banco de dados
	# -------------------------------------------------------------------------
	eval {
		my $sql = "INSERT INTO dadosContrato (
			idCliente, tipoContrato, idContratoAditivo,
			valorTotal, dataEntrada, valorEntrada, valorNegociado, parcelaNegociado,
			valorCaso, parcelaCaso, valorInvestimento, obsGeral, dataInclusao, statusContrato)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURDATE(), 1)
		";

		my $sth = $dbh->prepare($sql);
		$sth->execute(
			$cliente,
			$tipoContrato,
			($tipoContrato =~ /ADITIVO/ ? $idContratoAditivo : undef),
			$valorTotal,
			$vencimentoDB,
			$entradaInicial,
			$entradaRestante,
			($qtdParcelasEntrada ne '' ? $qtdParcelasEntrada : undef),
			$valorCaso,
			($qtdParcelasCaso ne '' ? $qtdParcelasCaso : undef),
			$valorExito,
			$observacoes
		);

		my $novoId = $dbh->last_insert_id(undef, undef, 'dadosContrato', 'idContrato');
		$json_response = { success => 1, message => "Contrato gravado com sucesso!", idContrato => $novoId };
	};

	if ($@) {
		&logError($logFile, "Erro interno ao gravar contrato: $@");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '500 Internal Server Error');
		my $respostaJson = to_json({ success => 0, message => "O servidor encontrou uma condi��o inesperada ao gravar o contrato." });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	print $query->header(-type => 'application/json', -charset => 'windows-1252');
	print to_json($json_response);
}

sub consultarDetalhes {
	my $idContrato = $query->param('id');

	unless ($idContrato && $idContrato =~ /^\d+$/) {
		&logError($logFile, "ID do contrato invalido ou nao fornecido para detalhes");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
		my $respostaJson = to_json({ message => "Dados incompletos. Verifique se todos os campos foram preenchidos." });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	my $frm_number = Number::Format->new(
		-thousands_sep     => '.', -decimal_point     => ',',
		-int_curr_symbol   => 'R$ ', -mon_thousands_sep => ',',
		-mon_decimal_point => '.',   -decimal_digits    => 2,
		-decimal_fill      => 1
	);

	my ($id, $statusContrato, $dataInclusao, $tipoContrato, $nomeCliente,
		$idContratoAditivo, $valorTotal, $dataEntrada, $valorEntrada, $valorNegociado,
		$parcelaNegociado, $valorCaso, $parcelaCaso, $valorInvestimento, $obsGeral, $dataConclusao);

	eval {
		my $sql = "
			SELECT
				p.idContrato,
				p.statusContrato,
				DATE_FORMAT(p.dataInclusao, '%d/%m/%Y'),
				p.tipoContrato,
				c.nome,
				p.idContratoAditivo,
				p.valorTotal,
				DATE_FORMAT(p.dataEntrada, '%d/%m/%Y'),
				p.valorEntrada,
				p.valorNegociado,
				p.parcelaNegociado,
				p.valorCaso,
				p.parcelaCaso,
				p.valorInvestimento,
				p.obsGeral,
				DATE_FORMAT(p.dataConclusaoContrato, '%d/%m/%Y %H:%i:%s')
			FROM dadosContrato p
			LEFT JOIN clientes c ON c.idCliente = p.idCliente
			WHERE p.idContrato = ?
		";
		my $sth = $dbh->prepare($sql);
		$sth->execute($idContrato);
		($id, $statusContrato, $dataInclusao, $tipoContrato, $nomeCliente,
			$idContratoAditivo, $valorTotal, $dataEntrada, $valorEntrada, $valorNegociado,
			$parcelaNegociado, $valorCaso, $parcelaCaso, $valorInvestimento, $obsGeral, $dataConclusao) = $sth->fetchrow_array();
	};

	if ($@) {
		&logError($logFile, "Erro interno ao consultar detalhes do contrato: $@");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '500 Internal Server Error');
		my $respostaJson = to_json({ message => "O servidor encontrou uma condicao inesperada." });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	unless ($id) {
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '404 Not Found');
		my $respostaJson = to_json({ message => "Contrato nao encontrado." });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	my $criarTituloSecao = sub {
		my ($titulo) = @_;
		return qq|<div class="form-group" style="background-color: #212121; padding: 15px; border-radius: 6px; margin-bottom: 5px; color:#FFFFFF; font-weight: bold;">$titulo</div>|;
	};

	my $abrirBoxConteudo = sub {
		return qq|<div class="form-group" style="background-color: #212121; padding: 15px; border-radius: 6px; margin-bottom: 20px;">|;
	};

	my $criarLinhaDetalhe = sub {
		my ($label, $valor) = @_;
		$valor = $valor || '-';
		return << "HTML";
<div class="row" style="margin-bottom: 5px;">
	<div class="col-sm-4 label-responsiva">$label:</div>
	<div class="col-sm-8" style="color: #FFFFFF;">$valor</div>
</div>
HTML
	};

	my $fecharBoxConteudo = sub {
		return qq|</div>|;
	};

	# Mapa de status
	my %statusMap = (1 => 'Ativo', 8 => 'Concluido', 9 => 'Inativo');
	my $statusTexto = $statusMap{$statusContrato} || 'N/D';

	# Formatacao de valores monetarios
	my $valorTotalFmt      = 'R$ ' . $frm_number->format_number($valorTotal || 0);
	my $valorEntradaFmt    = 'R$ ' . $frm_number->format_number($valorEntrada || 0);
	my $valorNegociadoFmt  = 'R$ ' . $frm_number->format_number($valorNegociado || 0);
	my $valorCasoFmt       = 'R$ ' . $frm_number->format_number($valorCaso || 0);

	# Soma para conferencia
	my $somaCalculada = ($valorEntrada || 0) + ($valorNegociado || 0) + ($valorCaso || 0);
	my $somaCalculadaFmt = 'R$ ' . $frm_number->format_number($somaCalculada);

	# --- Monta o HTML ---
	my $htmlConteudo = '';

	# === SECAO 1: DADOS GERAIS ===
	$htmlConteudo .= $criarTituloSecao->("1 - DADOS GERAIS DO CONTRATO");
	$htmlConteudo .= $abrirBoxConteudo->();
	$htmlConteudo .= $criarLinhaDetalhe->("ID Contrato", $id);
	$htmlConteudo .= $criarLinhaDetalhe->("Status", $statusTexto);
	$htmlConteudo .= $criarLinhaDetalhe->("Data de Inclusao", $dataInclusao);
	$htmlConteudo .= $criarLinhaDetalhe->("Tipo de Contrato", $tipoContrato);
	$htmlConteudo .= $criarLinhaDetalhe->("Cliente", $nomeCliente);
	if ($tipoContrato && $tipoContrato =~ /ADITIVO/) {
		$htmlConteudo .= $criarLinhaDetalhe->("ID Contrato Principal (Aditivo)", $idContratoAditivo);
	}
	if ($dataConclusao) {
		$htmlConteudo .= $criarLinhaDetalhe->("Data Conclusao", $dataConclusao);
	}
	$htmlConteudo .= $fecharBoxConteudo->();

	# === SECAO 2: VALORES E PAGAMENTO ===
	$htmlConteudo .= $criarTituloSecao->("2 - VALORES E PAGAMENTO");
	$htmlConteudo .= $abrirBoxConteudo->();
	$htmlConteudo .= $criarLinhaDetalhe->("Valor Total", $valorTotalFmt);
	$htmlConteudo .= $criarLinhaDetalhe->("Vencimento", $dataEntrada);
	$htmlConteudo .= $criarLinhaDetalhe->("Entrada Inicial (Principal)", $valorEntradaFmt);
	$htmlConteudo .= $criarLinhaDetalhe->("Entrada Restante (Negociada)", $valorNegociadoFmt);
	$htmlConteudo .= $criarLinhaDetalhe->("Parcelas Entrada", $parcelaNegociado);
	$htmlConteudo .= $criarLinhaDetalhe->("Valor Caso", $valorCasoFmt);
	$htmlConteudo .= $criarLinhaDetalhe->("Parcelas Caso", $parcelaCaso);
	$htmlConteudo .= $fecharBoxConteudo->();

	# === SECAO 3: EXITO E OBSERVACOES ===
	$htmlConteudo .= $criarTituloSecao->("3 - EXITO E OBSERVACOES");
	$htmlConteudo .= $abrirBoxConteudo->();

	my $valorExitoHtml = $valorInvestimento || '-';
	$valorExitoHtml =~ s/\n/<br>/g;
	$htmlConteudo .= qq|<div class="row" style="margin-bottom: 5px;">
	<div class="col-sm-4 label-responsiva">Valor do Exito:</div>
	<div class="col-sm-8" style="color: #FFFFFF; white-space: pre-wrap;">$valorExitoHtml</div>
</div>|;

	my $observacoesHtml = $obsGeral || '-';
	$observacoesHtml =~ s/\n/<br>/g;
	$htmlConteudo .= qq|<div class="row" style="margin-bottom: 5px;">
	<div class="col-sm-4 label-responsiva">Observacoes Gerais:</div>
	<div class="col-sm-8" style="color: #FFFFFF; white-space: pre-wrap;">$observacoesHtml</div>
</div>|;

	$htmlConteudo .= $fecharBoxConteudo->();

	print $query->header(-type => 'text/html', -charset => 'windows-1252');
	print encode('UTF-8', $htmlConteudo);
}

sub uploadAnexo {
	my $idContrato = $query->param('idContratoAnexo');

	unless ($idContrato && $idContrato =~ /^\d+$/) {
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
		my $respostaJson = to_json({ success => 0, message => "ID do contrato inv�lido ou n�o fornecido." });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	# Verificar se o contrato existe
	my ($existeContrato);
	eval {
		my $sql = "SELECT idContrato FROM dadosContrato WHERE idContrato = ?";
		my $sth = $dbh->prepare($sql);
		$sth->execute($idContrato);
		($existeContrato) = $sth->fetchrow_array();
	};
	unless ($existeContrato) {
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
		my $respostaJson = to_json({ success => 0, message => "Contrato n�o encontrado." });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	my ($caminhoAnexoContrato, $caminhoAnexoComprovante);

	eval {
		my %camposParaAtualizar;
		my $atualizouContrato = 0;

		# Processar upload do contrato assinado
		my $arquivoContrato = $query->upload('uploadContratoAssinado');
		if ($arquivoContrato) {
			my $nomeOriginal = $query->param('uploadContratoAssinado');
			my ($basename, $path, $suffix) = fileparse($nomeOriginal, qr/\.[^.]*/);

			my $nomeNovo = "${basename}_contrato_${idContrato}_" . time() . $suffix;
			$nomeNovo = &removeAcentos($nomeNovo);

			my $caminhoCompleto = File::Spec->catfile($CaminhoFisicoDownload, $nomeNovo);

			open(my $out, '>', $caminhoCompleto) or die "Nao foi possivel abrir $caminhoCompleto: $!";
			binmode $out;
			while (my $buffer = <$arquivoContrato>) {
				print $out $buffer;
			}
			close $out;

			$camposParaAtualizar{anexoContratoAssinado} = $nomeNovo;
			$atualizouContrato = 1;
			$caminhoAnexoContrato = $caminhoCompleto;
		}

		# Processar upload do comprovante de pagamento
		my $arquivoComprovante = $query->upload('uploadComprovantePagamento');
		if ($arquivoComprovante) {
			my $nomeOriginal = $query->param('uploadComprovantePagamento');
			my ($basename, $path, $suffix) = fileparse($nomeOriginal, qr/\.[^.]*/);

			my $nomeNovo = "${basename}_comprovante_${idContrato}_" . time() . $suffix;
			$nomeNovo = &removeAcentos($nomeNovo);

			my $caminhoCompleto = File::Spec->catfile($CaminhoFisicoDownload, $nomeNovo);

			open(my $out, '>', $caminhoCompleto) or die "Nao foi possivel abrir $caminhoCompleto: $!";
			binmode $out;
			while (my $buffer = <$arquivoComprovante>) {
				print $out $buffer;
			}
			close $out;

			$camposParaAtualizar{comprovantePagamento} = $nomeNovo;
			$caminhoAnexoComprovante = $caminhoCompleto;
		}

		unless ($atualizouContrato || $arquivoComprovante) {
			print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
			my $respostaJson = to_json({ success => 0, message => "Nenhum arquivo foi enviado." });
			print encode('windows-1252', $respostaJson);
			exit;
		}

		my $sqlSet = join ", ", map { "$_ = ?" } keys %camposParaAtualizar;
		my @params = values %camposParaAtualizar;

		$sqlSet .= ", dataAnexoContrato = NOW()" if $atualizouContrato;

		push @params, $idContrato;

		my $sql = "UPDATE dadosContrato SET $sqlSet WHERE idContrato = ?";
		my $sth = $dbh->prepare($sql);
		$sth->execute(@params);

		# Se anexou contrato assinado, atualizar status do cliente para 8 (Cliente Ativo)
		if ($atualizouContrato) {
			my $sqlGetCliente = "SELECT idCliente FROM dadosContrato WHERE idContrato = ?";
			my $sthGetCliente = $dbh->prepare($sqlGetCliente);
			$sthGetCliente->execute($idContrato);
			my ($idClienteContrato) = $sthGetCliente->fetchrow_array();

			if ($idClienteContrato) {
				eval {
					my $sqlUpdateCliente = "UPDATE clientes SET status = 8, dataAtualizacao = NOW() WHERE idCliente = ?";
					my $sthUpdateCliente = $dbh->prepare($sqlUpdateCliente);
					$sthUpdateCliente->execute($idClienteContrato);

					my ($idLegalOne, $erroLegalOne) = &cadastrarContatoLegalOne($idClienteContrato);
					if ($erroLegalOne) {
						&logError($logFile, "LegalOne: Erro no cadastro do cliente $idClienteContrato para o contrato $idContrato: $erroLegalOne");
					}
				};
				if ($@) {
					&logError($logFile, "LegalOne: Excecao ao cadastrar contato do cliente $idClienteContrato: $@");
				}
			}
		}
	};

	if ($@) {
		&logError($logFile, "Erro interno ao fazer upload de anexo: $@");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '500 Internal Server Error');
		my $respostaJson = to_json({ success => 0, message => "O servidor encontrou uma condi��o inesperada ao salvar o(s) arquivo(s)." });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	# -------------------------------------------------------------------------
	# Disparo de e-mail para o financeiro
	# -------------------------------------------------------------------------
	eval {
		&dispararEmailFinanceiro($idContrato, $caminhoAnexoContrato, $caminhoAnexoComprovante);
	};
	if ($@) {
		&logError($logFile, "Erro ao enviar e-mail de notificacao do contrato $idContrato: $@");
	}

	print $query->header(-type => 'application/json', -charset => 'windows-1252');
	print to_json({ success => 1, message => "Arquivo(s) enviado(s) com sucesso!" });
}

sub editarContrato {
	my $idContrato = $query->param('id');

	unless ($idContrato && $idContrato =~ /^\d+$/) {
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
		return print to_json({ message => "ID do contrato inv�lido." });
	}

	my $dados;
	eval {
		my $sql = "SELECT idContrato, idCliente, tipoContrato, idContratoAditivo,
			valorTotal, DATE_FORMAT(dataEntrada, '%d/%m/%Y') AS vencimento,
			valorEntrada, valorNegociado, parcelaNegociado, valorCaso, parcelaCaso,
			valorInvestimento, obsGeral
			FROM dadosContrato WHERE idContrato = ?";
		my $sth = $dbh->prepare($sql);
		$sth->execute($idContrato);
		$dados = $sth->fetchrow_hashref();

		if ($dados) {
			foreach my $key (keys %$dados) {
				if (defined $dados->{$key} && !ref($dados->{$key}) && $dados->{$key} =~ /[^\x00-\x7F]/) {
					$dados->{$key} = uri_escape_utf8($dados->{$key});
				}
			}
		}
	};

	if ($@ or !$dados) {
		&logError($logFile, "Erro ao buscar dados do contrato $idContrato: $@");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '500 Internal Server Error');
		return print to_json({ message => "N�o foi poss�vel carregar os dados do contrato." });
	}

	print $query->header(-type => 'application/json', -charset => 'windows-1252');
	print to_json({ success => 1, data => $dados });
}

sub atualizarContrato {
	my $json_response;

	my $idContrato         = $query->param('idContrato');
	my $cliente            = $query->param('cliente');
	my $tipoContrato       = $query->param('tipoContrato');
	my $idContratoAditivo  = $query->param('idContratoAditivo');
	my $valorTotal         = $query->param('valorTotal');
	my $vencimento         = $query->param('vencimento');
	my $entradaInicial     = $query->param('entradaInicial');
	my $entradaRestante    = $query->param('entradaRestante');
	my $qtdParcelasEntrada = $query->param('qtdParcelasEntrada');
	my $valorCaso          = $query->param('valorCaso');
	my $qtdParcelasCaso    = $query->param('qtdParcelasCaso');
	my $valorExito         = $query->param('valorExito');
	my $observacoes        = $query->param('observacoes');

	my @erros;

	push @erros, "ID do contrato inv�lido" unless ($idContrato && $idContrato =~ /^\d+$/);
	push @erros, "O campo 'Cliente' � obrigat�rio"          unless $cliente;
	push @erros, "O campo 'Tipo Contrato' � obrigat�rio"    unless $tipoContrato;
	push @erros, "O campo 'Valor Total' � obrigat�rio"      unless $valorTotal;
	push @erros, "O campo 'Vencimento' � obrigat�rio"       unless $vencimento;
	push @erros, "O campo 'Entrada Inicial' � obrigat�rio"  unless $entradaInicial;
	push @erros, "O campo 'Entrada Restante' � obrigat�rio" unless $entradaRestante;
	push @erros, "O campo 'Valor Caso' � obrigat�rio"       unless $valorCaso;
	push @erros, "O campo 'Valor do �xito' � obrigat�rio"  unless $valorExito;
	push @erros, "O campo 'Observa��es gerais' � obrigat�rio" unless $observacoes;

	if ($tipoContrato && $tipoContrato =~ /ADITIVO/) {
		unless ($idContratoAditivo && $idContratoAditivo =~ /^\d+$/) {
			push @erros, "O campo 'ID Contrato Principal' � obrigat�rio para contratos do tipo ADITIVO.";
		}
	}

	if ($vencimento && $vencimento !~ m|^\d{2}/\d{2}/\d{4}$|) {
		push @erros, "O campo 'Vencimento' deve estar no formato dd/mm/aaaa.";
	}

	if ($cliente && $cliente !~ /^\d+$/) {
		push @erros, "Cliente inv�lido.";
	}

	if (defined $qtdParcelasEntrada && $qtdParcelasEntrada ne '' && $qtdParcelasEntrada !~ /^\d+$/) {
		push @erros, "O campo 'Parcelas entrada' deve ser um n\xfamero inteiro.";
	}
	if (defined $qtdParcelasCaso && $qtdParcelasCaso ne '' && $qtdParcelasCaso !~ /^\d+$/) {
		push @erros, "O campo 'Parcelas caso' deve ser um n\xfamero inteiro.";
	}

	if (scalar @erros > 0) {
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
		my $respostaJson = to_json({ success => 0, message => join(" ", @erros) });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	my $converterMoeda = sub {
		my ($valor) = @_;
		return 0 unless $valor;
		$valor =~ s/\.//g;
		$valor =~ s/,/./;
		return $valor;
	};

	$valorTotal      = $converterMoeda->($valorTotal);
	$entradaInicial  = $converterMoeda->($entradaInicial);
	$entradaRestante = $converterMoeda->($entradaRestante);
	$valorCaso       = $converterMoeda->($valorCaso);

	{
		my $somaEsperada = sprintf("%.2f", $entradaInicial + $entradaRestante + $valorCaso);
		my $valorTotalFmt = sprintf("%.2f", $valorTotal);
		if ($valorTotalFmt ne $somaEsperada) {
			print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
			my $respostaJson = to_json({ success => 0, message => "O Valor Total (R\$ $valorTotalFmt) deve ser igual a soma da Entrada Inicial + Entrada Restante + Valor Caso (R\$ $somaEsperada)." });
			print encode('windows-1252', $respostaJson);
			exit;
		}
	}

	my $vencimentoDB = undef;
	if ($vencimento =~ m|^(\d{2})/(\d{2})/(\d{4})$|) {
		$vencimentoDB = "$3-$2-$1";
	}

	my ($existeCliente);
	eval {
		my $sql = "SELECT idCliente FROM clientes WHERE idCliente = ?";
		my $sth = $dbh->prepare($sql);
		$sth->execute($cliente);
		($existeCliente) = $sth->fetchrow_array();
	};
	unless ($existeCliente) {
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
		my $respostaJson = to_json({ success => 0, message => "Cliente n�o encontrado na base de dados." });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	if ($tipoContrato =~ /ADITIVO/ && $idContratoAditivo) {
		my ($existeContrato);
		eval {
			my $sql = "SELECT idContrato FROM dadosContrato WHERE idContrato = ?";
			my $sth = $dbh->prepare($sql);
			$sth->execute($idContratoAditivo);
			($existeContrato) = $sth->fetchrow_array();
		};
		unless ($existeContrato) {
			print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '400 Bad Request');
			my $respostaJson = to_json({ success => 0, message => "O contrato principal (ID $idContratoAditivo) n�o foi encontrado." });
			print encode('windows-1252', $respostaJson);
			exit;
		}
	}

	eval {
		my $sql = "UPDATE dadosContrato SET
			idCliente = ?, tipoContrato = ?, idContratoAditivo = ?,
			valorTotal = ?, dataEntrada = ?, valorEntrada = ?, valorNegociado = ?, parcelaNegociado = ?,
			valorCaso = ?, parcelaCaso = ?, valorInvestimento = ?, obsGeral = ?
			WHERE idContrato = ?";

		my $sth = $dbh->prepare($sql);
		$sth->execute(
			$cliente,
			$tipoContrato,
			($tipoContrato =~ /ADITIVO/ ? $idContratoAditivo : undef),
			$valorTotal,
			$vencimentoDB,
			$entradaInicial,
			$entradaRestante,
			($qtdParcelasEntrada ne '' ? $qtdParcelasEntrada : undef),
			$valorCaso,
			($qtdParcelasCaso ne '' ? $qtdParcelasCaso : undef),
			$valorExito,
			$observacoes,
			$idContrato
		);

		$json_response = { success => 1, message => "Contrato atualizado com sucesso!" };
	};

	if ($@) {
		&logError($logFile, "Erro interno ao atualizar contrato: $@");
		print $query->header(-type => 'application/json', -charset => 'windows-1252', -status => '500 Internal Server Error');
		my $respostaJson = to_json({ success => 0, message => "O servidor encontrou uma condi��o inesperada ao atualizar o contrato." });
		print encode('windows-1252', $respostaJson);
		exit;
	}

	print $query->header(-type => 'application/json', -charset => 'windows-1252');
	print to_json($json_response);
}

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#- Select do Cliente
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
my $opcoesCliente = '';
eval {
	my $sql = "SELECT idCliente, nome FROM clientes WHERE status != 9 ORDER BY nome ASC";
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	while (my ($id, $nome) = $sth->fetchrow_array()) {
		$opcoesCliente .= "<option value='$id'>$nome</option>";
	}
	$dbh->disconnect();
};
if ($@) {
	&logError($logFile, "Erro ao buscar lista de clientes: $@");
	$opcoesCliente = "<option value=''>Erro ao carregar</option>";
}

my $Direitos1 = ($Direitos[1] eq 'S') ? 'true' : 'false';
my $Direitos2 = ($Direitos[2] eq 'S') ? 'true' : 'false';

print <<HTML;
<script>
	$initSelect2
	$requiredField
	$validaCampos
	const Direitos1 = $Direitos1;
    const Direitos2 = $Direitos2;
</script>
<style>
	.label-responsiva {
       	text-align: right;
       	color: #B7872D;
       	font-weight: bold;
    }

    \@media (max-width: 767px) {
       	.label-responsiva {
          	text-align: left !important;
          	margin-bottom: 2px;
       	}

        .modal-dialog {
            width: 95%;
            margin: 10px auto;
        }
    }
    .modal-dialog {
        width: 85%;
        height: auto;
        align-items: center;
    }
    .modal-content {
       	height: auto;
        border-radius: 1;
    }

	#tabelaContratos tbody td {
        font-weight: bold;
    }

	$defaultCssDataTables

	.modal-content {
		position: relative;
	}

    .loading-spinner-overlay {
        position: absolute; /* Posicionamento absoluto em rela��o ao modal-content */
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(23, 23, 23, 0.85);
        z-index: 10; /* Garante que o overlay fique por cima de todo o conte�do */
        display: none;

        /* Flexbox para centralizar o conte�do do spinner (�cone e texto) */
        justify-content: center;
        align-items: center;
        flex-direction: column;
    }

	$cssSelect2Single
	$cssSelect2Multi
</style>

<div id="modalDownloadsContainer">
	<div class="modal fade" id="modal-downloads" tabindex="-1" role="dialog">
		<div class="modal-dialog" role="document">
			<div class="modal-content" style="background-color: #171717; color: #FFFFFF; border-radius: 8px;">
				<div class="loading-spinner-overlay text-center">
					<i class="fas fa-refresh fa-spin fa-3x" style="color: #B7872D;"></i>
					<p style="color: white; margin-top: 10px;">Carregando dados...</p>
				</div>

				<div class="modal-header" style="background-color: #B7872D; border-top-left-radius: 8px; border-top-right-radius: 8px; border-bottom: none;">
					<h4 class="modal-title" style="font-weight: bold; color: #FFFFFF;">Arquivos do Contrato</h4>
				</div>

				<div class="modal-body" style="padding: 20px;">
					<div id="listaDownloads">
					</div>
				</div>

				<div class="modal-footer" style="border: none; background-color: #303030; border-bottom-left-radius: 8px; border-bottom-right-radius: 8px;">
					<button type="button" class="btn btn-primary btn-sm" onclick="salvarAnexos()"><i class="fa fa-upload"></i> Enviar Arquivos</button>
					<button type="button" class="btn btn-secondary btn-sm" data-dismiss="modal" style="background-color: #B7872D; border: none; color: #FFFFFF;">Fechar</button>
				</div>
			</div>
		</div>
	</div>
</div>


<div id="modalDetalhesContainer">
	<div class="modal fade" id="modal-detalhes" tabindex="-1" role="dialog">
		<div class="modal-dialog" role="document">
			<div class="modal-content" style="background-color: #171717; color: #FFFFFF; border-radius: 8px;">
				<div class="loading-spinner-overlay text-center" id="spinnerDetalhes">
					<i class="fas fa-refresh fa-spin fa-3x" style="color: #B7872D;"></i>
					<p style="color: white; margin-top: 10px;">Carregando detalhes...</p>
				</div>

				<div class="modal-header" style="background-color: #B7872D; border-top-left-radius: 8px; border-top-right-radius: 8px; border-bottom: none;">
					<h4 class="modal-title" style="font-weight: bold; color: #FFFFFF;"><i class="fa fa-info-circle"></i> Detalhes do Contrato</h4>
				</div>

				<div class="modal-body" style="padding: 20px; max-height: 70vh; overflow-y: auto;">
					<div id="conteudoDetalhes">
					</div>
				</div>

				<div class="modal-footer" style="border: none; background-color: #303030; border-bottom-left-radius: 8px; border-bottom-right-radius: 8px;">
					<button type="button" class="btn btn-secondary btn-sm" data-dismiss="modal" style="background-color: #B7872D; border: none; color: #FFFFFF;">Fechar</button>
				</div>
			</div>
		</div>
	</div>
</div>

<div class="content-wrapper">
	<section class="content-header"><h1>$tituloPrograma <small> - $programa - $versao</small></h1></section>
	<section class="content">
		<div class="row">
			<div class="col-md-12">
				<div class="box box-solid box-primary" id="boxFiltros">
					<div class="overlay" id="divProcessando" style="display: none">
						<i class="fa fa-refresh fa-spin"></i>
					</div>

					<div class="box-header with-border">
						<h3 class="box-title">1 - Painel de Opera��es</h3>
						<div class="box-tools pull-right">
							<button type="button" class="btn btn-box-tool" data-widget="collapse" id="btnAbreFiltros"><i id="boxFiltrosIcon" class="fa fa-minus"></i></button>
						</div>
					</div>

					<div class="box-body">
						<form id="Form1" name="Form1" class="form-horizontal" autocomplete="off">
							<input type="hidden" id="idContrato" name="idContrato" value="">
							<div id="linhaCadastro">
								<div class="form-group">
									<label for="cliente" class="col-sm-1 control-label">Cliente:</label>
									<div class="col-sm-2">
										<select id="cliente" name="cliente" class="form-control select2" onblur="requiredField(this);" required="true">
											<option value=""></option>
											$opcoesCliente
										</select>
									</div>

									<label for="tipoContrato" class="col-sm-2 control-label">Tipo Contrato:</label>
									<div class="col-sm-3">
										<select id='tipoContrato' name='tipoContrato' class='form-control select2-multi' multiple='multiple' required="true" onchange="verificaOpcao()">
											<option value='ADITIVO'>ADITIVO</option>
											<option value='AMBIENTAL'>AMBIENTAL</option>
											<option value='CRIMINAL'>CRIMINAL</option>
											<option value='LEIL�O'>LEIL�O</option>
											<option value='NAC'>NAC</option>
											<option value='PRP'>PRP</option>
											<option value='RECUPERA��O JUDICIAL'>RECUPERA��O JUDICIAL</option>
											<option value='TRIBUT�RIO'>TRIBUT�RIO</option>
											<option value='VENDA CASADA'>VENDA CASADA</option>
										</select>
									</div>

									<div id="idContratoAditivoDiv" style="display:none;">
										<label for="idContratoAditivo" class="col-sm-2 control-label">ID Contrato Principal:</label>
										<div class="col-sm-1">
											<input type="number" class="form-control" id="idContratoAditivo" name="idContratoAditivo">
										</div>
									</div>
								</div>

								<div class="form-group">
									<label for="valorTotal" class="col-sm-1 control-label">Valor Total:</label>
									<div class="col-sm-2">
										<div class="input-group">
											<div class="input-group-addon bg-green">
												<i class="fa fa-usd"></i>
											</div>
											<input type="text" class="form-control text-right" id="valorTotal" name="valorTotal"
												   maxlength="20" onblur="requiredField(this);" required="true" readonly
												   style="background-color: #eee; font-weight: bold;"
												   title="Calculado automaticamente: Entrada Inicial + Entrada Restante + Valor Caso">
										</div>
									</div>

									<label for="vencimento" class="col-sm-2 control-label">Vencimento:</label>
									<div class="col-sm-2">
										<div class="input-group">
											<div class="input-group-addon bg-black">
												<i class="fa fa-calendar"></i>
											</div>
											<input type="text" id="vencimento" name="vencimento" required="true" onblur="requiredField(this);" class="form-control mostraCalendario" data-inputmask="'alias': 'dd/mm/yyyy'" data-mask>
										</div>
									</div>
								</div>

								<div class="form-group">
									<label for="entradaInicial" class="col-sm-1 control-label">Entrada inicial:</label>
									<div class="col-sm-2">
										<div class="input-group">
											<div class="input-group-addon bg-green">
												<i class="fa fa-usd"></i>
											</div>
											<input type="text" class="form-control text-right" id="entradaInicial" name="entradaInicial"
												   maxlength="20" onblur="requiredField(this);" required="true" onKeyUp="mascaraMoeda(this, event);">
										</div>
									</div>

									<label for="entradaRestante" class="col-sm-2 control-label">Entrada restante:</label>
									<div class="col-sm-2">
										<div class="input-group">
											<div class="input-group-addon bg-green">
												<i class="fa fa-usd"></i>
											</div>
											<input type="text" class="form-control text-right" id="entradaRestante" name="entradaRestante"
												   maxlength="20" onblur="requiredField(this);" required="true" onKeyUp="mascaraMoeda(this, event);">
										</div>
									</div>

									<label for="qtdParcelasEntrada" class="col-sm-2 control-label">Parcelas entrada:</label>
									<div class="col-sm-1">
										<div class="input-group">
											<div class="input-group-addon bg-black">
												<span>X</span>
											</div>
											<input type="number" class="form-control" id="qtdParcelasEntrada" name="qtdParcelasEntrada" min="0">
										</div>
									</div>
								</div>

								<div class="form-group">
									<label for="valorCaso" class="col-sm-1 control-label">Valor caso:</label>
									<div class="col-sm-2">
										<div class="input-group">
											<div class="input-group-addon bg-green">
												<i class="fa fa-usd"></i>
											</div>
											<input type="text" class="form-control text-right" id="valorCaso" name="valorCaso"
												   maxlength="20" onblur="requiredField(this);" required="true" onKeyUp="mascaraMoeda(this, event);">
										</div>
									</div>

									<label for="qtdParcelasCaso" class="col-sm-2 control-label">Parcelas caso:</label>
									<div class="col-sm-1">
										<div class="input-group">
											<div class="input-group-addon bg-black">
												<span>X</span>
											</div>
											<input type="number" class="form-control" id="qtdParcelasCaso" name="qtdParcelasCaso" min="0">
										</div>
									</div>
								</div>

								<div class="form-group">
									<label for="valorExito" class="col-sm-1 control-label">Valor do �xito:</label>
									<div class="col-sm-10">
										<textarea
											class="form-control" id="valorExito" name="valorExito"
											rows="4" placeholder="Informe o valor e condi��es de pagamento do �xito..."
											style="resize: none;" onblur="requiredField(this);" required="true"></textarea>
									</div>
								</div>

								<div class="form-group">
									<label for="observacoes" class="col-sm-1 control-label">Observa��es gerais:</label>
									<div class="col-sm-10">
										<textarea
											class="form-control" id="observacoes" name="observacoes"
											rows="4" placeholder="Observa��es gerais sobre o contrato..."
											style="resize: none;" onblur="requiredField(this);" required="true"></textarea>
									</div>
								</div>
							</div>

							<div id="linhaFiltros" style="display:none;">
								<div class="form-group">
									<label for="idContratoFiltro" class="col-sm-1 control-label">ID:</label>
									<div class="col-sm-2">
										<input type="number" class="form-control" id="idContratoFiltro" name="idContratoFiltro">
									</div>

									<label for="tipoContratoFiltro" class="col-sm-1 control-label">Tipo Contrato:</label>
									<div class="col-sm-2">
										<select id='tipoContratoFiltro' name='tipoContratoFiltro' class='form-control'>
											<option value=''></option>
											<option value='PRP'>PRP</option>
											<option value='LEIL�O'>LEIL�O</option>
											<option value='RECUPERA��O JUDICIAL'>RECUPERA��O JUDICIAL</option>
											<option value='TRIBUT�RIO'>TRIBUT�RIO</option>
											<option value='ADITIVO'>ADITIVO</option>
											<option value='AMBIENTAL'>AMBIENTAL</option>
											<option value='NAC'>NAC</option>
											<option value='VENDA CASADA'>VENDA CASADA</option>
											<option value='CRIMINAL'>CRIMINAL</option>
										</select>
									</div>

									<label for="clienteFiltro" class="col-sm-1 control-label">Cliente:</label>
									<div class="col-sm-2">
										<select id="clienteFiltro" name="clienteFiltro" class="form-control select2">
											<option value=""></option>
											$opcoesCliente
										</select>
									</div>
								</div>

								<div class="form-group">
									<label for="dataInicial" class="col-sm-1 control-label">Per�odo:</label>
									<div class="col-sm-2">
										<div class="input-group">
											<div class="input-group-addon bg-black"><i class="fa fa-calendar"></i></div>
											<input type="text" id="dataInicial" name="dataInicial" class="form-control mostraCalendario" data-inputmask="'alias': 'dd/mm/yyyy'" data-mask>
										</div>
									</div>

									<label for="dataFinal" class="col-sm-1 control-label">at�:</label>
									<div class="col-sm-2">
										<div class="input-group">
											<div class="input-group-addon bg-black"><i class="fa fa-calendar"></i></div>
											<input type="text" id="dataFinal" name="dataFinal" class="form-control mostraCalendario" data-inputmask="'alias': 'dd/mm/yyyy'" data-mask>
										</div>
									</div>

									<label class="col-sm-1 control-label">Status:</label>
									<div class="col-sm-2">
										<div class="input-group">
											<div class="input-group-addon bg-black">
												<i class="fa fa-cogs"></i>
											</div>
											<select id="status" name="status" class="form-control">
												<option value=''></option>
												<option value="1">ATIVO</option>
												<option value="8">CONCLU�DO</option>
												<option value="9">INATIVO</option>
											</select>
										</div>
									</div>
								</div>
							</div>
						</form>
					</div>

					<div class="box-footer">
						<button type="button" class="btn btn-info" onClick="javascript:window.location='/cgi-bin/$arquivo';">
							<span class="glyphicon glyphicon-asterisk"></span>&nbsp;Novo&nbsp;
						</button>

						<button type="button" class="btn btn-primary" id="btnGravar" name="btnGravar" onClick="if (validaCampos(document.getElementById('Form1'))) { gravar(); }">
							<span class="glyphicon glyphicon-save"></span>&nbsp;Gravar&nbsp;
						</button>

						<button type="button" class="btn btn-warning" id="btnConsultar" style="display:none;">
							<span class="glyphicon glyphicon-search"></span>&nbsp;Consultar&nbsp;
						</button>

						<button type="button" class="btn btn-warning" id="btnFiltrar" onClick="mostrarFiltros();">
							<span class="glyphicon glyphicon-edit"></span>&nbsp;Filtros&nbsp;
						</button>
					</div>
				</div>
			</div>
		</div>

		<div class="row">
			<div class="col-md-12">
				<div class="box box-solid box-default collapsed-box" id="boxConsulta">
					<div class="box-header with-border">
						<h3 class="box-title">Dados - Consulta</h3>
						<div class="box-tools pull-right">
							<button type="button" class="btn btn-box-tool" data-widget="collapse" id="btnAbreConsulta"><i id="boxConsultaIcon" class="fa fa-plus"></i></button>
						</div>
					</div>
					<div class="box-body">
						<div class="table-responsive">
							<table id="tabelaContratos" class="table table-hover table-bordered table-striped default-css-data-tables" style="width:100%;">
								<thead>
								<tr style="background-color:#303030; color:white;">
									<th style="text-align:center;">ID</th>
									<th style="text-align:center;">Status</th>
									<th style="text-align:center;">Data</th>
									<th style="text-align:center;">Tipo</th>
									<th style="text-align:center;">Nome</th>
									<th style="text-align:center;">Valor Contrato</th>
									<th style="text-align:center;">Dt. Contrato Assinado</th>
									<th style="text-align:center;">Dt. Conclus�o</th>
									<th style="text-align:center;">A��es</th>
								</tr>
								</thead>
								<tbody>
								</tbody>
							</table>
						</div>
					</div>
				</div>
			</div>
		</div>
	</section>
</div>
HTML

print <<'HTML';
<script>
	var modoEdicao = false;

	document.addEventListener("DOMContentLoaded", function() {
		initSelect2();

       // Auto-calcular Valor Total quando alterar campos de entrada/caso
       ['entradaInicial', 'entradaRestante', 'valorCaso'].forEach(function(id) {
           var campo = document.getElementById(id);
           if (campo) {
               campo.addEventListener('blur', calcularValorTotal);
           }
       });
    });

    function updateFileName(input) {
    	const fileDisplayName = input.nextElementSibling; // O <div> que mostra o nome
    	if (fileDisplayName) {
        	const fileName = input.files.length > 0 ? input.files[0].name : 'Nenhum arquivo selecionado';
        	const textColor = input.files.length > 0 ? '#4CAF50' : '#aaa';
        	fileDisplayName.textContent = fileName;
        	fileDisplayName.style.color = textColor;
    	}
	}

	function verificaOpcao() {
		var selectedValues = $('#tipoContrato').val() || [];
        var divIdContratoAditivo = document.getElementById('idContratoAditivoDiv');
        var campoIdContratoAditivo = document.getElementById('idContratoAditivo');

        if (selectedValues.indexOf('ADITIVO') !== -1) {
            divIdContratoAditivo.style.display = '';
            campoIdContratoAditivo.required = true;
            campoIdContratoAditivo.setAttribute('onblur', 'requiredField(this);');
        } else {
            divIdContratoAditivo.style.display = 'none';
            campoIdContratoAditivo.required = false;
            campoIdContratoAditivo.removeAttribute('onblur');
        }
	}

	function mostrarFiltros() {
		document.getElementById('btnGravar').style.display = 'none';
		document.getElementById('btnConsultar').style.display = 'inline-block';
		document.getElementById('btnFiltrar').style.display = 'none';

		document.getElementById('linhaFiltros').style.display = '';
		document.getElementById('linhaCadastro').style.display = 'none';
	}

	function editarContrato(idContrato) {
		const url = `painel_contratos.pl?acao=EDITAR_CONTRATO&id=${idContrato}&nocache=${new Date().getTime()}`;

		fetch(url)
		.then(response => response.json())
		.then(data => {
			if (data.success) {
				const contrato = data.data;

				const decodeValue = (value) => {
					if (!value) return '';
					try {
						return decodeURIComponent(value);
					} catch (e) {
						return value;
					}
				};

				const formatMoedaEdit = (valor) => {
					if (!valor) return '0,00';
					var num = parseFloat(valor);
					return num.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.');
				};

				document.getElementById('idContrato').value = contrato.idContrato;
				$('#cliente').val(contrato.idCliente).trigger('change');
				// Seta valores do multi-select tipoContrato a partir da string CSV
				var tiposArray = decodeValue(contrato.tipoContrato).split(',').map(function(v){ return v.trim(); }).filter(function(v){ return v !== ''; });
				$('#tipoContrato').val(tiposArray).trigger('change');
				verificaOpcao();
				if (contrato.idContratoAditivo) {
					document.getElementById('idContratoAditivo').value = contrato.idContratoAditivo;
				}
				document.getElementById('entradaInicial').value = formatMoedaEdit(contrato.valorEntrada);
				document.getElementById('entradaRestante').value = formatMoedaEdit(contrato.valorNegociado);
				document.getElementById('qtdParcelasEntrada').value = contrato.parcelaNegociado || '';
				document.getElementById('valorCaso').value = formatMoedaEdit(contrato.valorCaso);
				document.getElementById('qtdParcelasCaso').value = contrato.parcelaCaso || '';
				document.getElementById('valorTotal').value = formatMoedaEdit(contrato.valorTotal);
				document.getElementById('vencimento').value = contrato.vencimento || '';
				document.getElementById('valorExito').value = decodeValue(contrato.valorInvestimento);
				document.getElementById('observacoes').value = decodeValue(contrato.obsGeral);

				modoEdicao = true;
				document.getElementById('btnGravar').innerHTML = '<span class="glyphicon glyphicon-save"></span>&nbsp;Atualizar&nbsp;';

				document.getElementById('linhaCadastro').style.display = '';
				document.getElementById('linhaFiltros').style.display = 'none';
				document.getElementById('btnGravar').style.display = 'inline-block';
				document.getElementById('btnConsultar').style.display = 'none';
				document.getElementById('btnFiltrar').style.display = 'inline-block';

				window.scrollTo(0, 0);
			} else {
				Swal.fire("Erro!", data.message || "Nao foi possivel carregar os dados.", "error");
			}
		})
		.catch(error => {
			Swal.fire("Erro de comunicacao!", "Nao foi possivel conectar ao servidor.", "error");
		});
	}

	String.prototype.reverse = function(){
        return this.split('').reverse().join('');
    };

	function mascaraMoeda(campo, evento) {
        let tecla = (!evento) ? window.event.keyCode : evento.which;
        let valor  =  campo.value.replace(/[^\d]+/gi,'').reverse();

        let resultado  = "";
        let mascara = "###.###.###.###.###,##".reverse();

        for (let x=0, y=0; x<mascara.length && y<valor.length;) {
            if (mascara.charAt(x) != '#') {
                resultado += mascara.charAt(x);
                x++;
            } else {
                resultado += valor.charAt(y);
                  y++;
                  x++;
            }
          }
        campo.value = resultado.reverse();
    }

    //--------------------------------------------------------------------------------
    // FUNCAO PARA GRAVAR CONTRATO
    //--------------------------------------------------------------------------------
    function gravar() {
    	// Validacao frontend: valorTotal = entradaInicial + entradaRestante + valorCaso
    	if (!validarValorTotal()) return;

    	const url = `painel_contratos.pl?nocache=${new Date().getTime()}`;

    	// Captura os dados do formul�rio
    	const formData = new FormData(document.getElementById('Form1'));

    	// Coleta valores do multi-select tipoContrato, ordena alfabeticamente e concatena com ", "
    	formData.delete('tipoContrato');
    	var tiposSelecionados = $('#tipoContrato').val() || [];
    	tiposSelecionados.sort();
    	formData.append('tipoContrato', tiposSelecionados.join(', '));

    	if (modoEdicao) {
    		formData.append('acao', 'ATUALIZAR_CONTRATO');
    	} else {
    		formData.append('acao', 'GRAVAR_CONTRATO');
    	}

    	// Exibe o indicador de processamento
    	document.getElementById('divProcessando').style.display = '';

    	fetch(url, {
        	method: 'POST',
        	body: formData
    	})
    	.then(response => {
        	if (!response.ok) {
            	return response.json().then(err => Promise.reject(err));
        	}
        	return response.json();
    	})
    	.then(data => {
        	document.getElementById('divProcessando').style.display = 'none';
        	if (data.success) {
            	Swal.fire({
                	title: "Sucesso!",
                	text: data.message + (data.idContrato ? " (ID: " + data.idContrato + ")" : ""),
                	icon: "success",
                	confirmButtonText: "OK"
            	}).then(() => {
                	window.location.href = "painel_contratos.pl";
            	});
        	} else {
            	Swal.fire("Erro!", data.message || "Ocorreu um erro ao gravar o contrato.", "error");
        	}
    	})
    	.catch(error => {
        	document.getElementById('divProcessando').style.display = 'none';
        	const errorMessage = error.message || "Ocorreu um erro na requisicao.";
        	Swal.fire("Erro!", errorMessage, "error");
    	});
	}

    function mostrarModalDownloads(idContrato) {
        const url = `painel_contratos.pl?acao=CONSULTAR_ANEXOS&id=${idContrato}&nocache=${new Date().getTime()}`;
        const modal = $('#modal-downloads');
        const spinnerOverlay = modal.find('.loading-spinner-overlay');
        const contentDiv = $('#listaDownloads');

        contentDiv.empty(); // Limpa o conte�do anterior
        spinnerOverlay.css('display', 'flex');
        modal.modal('show');

        fetch(url)
        .then(response => {
            if (!response.ok) {
                return response.json().then(err => Promise.reject(err));
            }
            return response.text();
        })
        .then(html => {
            contentDiv.html(html);
            spinnerOverlay.hide();
        })
        .catch(error => {
            spinnerOverlay.hide();
            modal.modal('hide');
            Swal.fire("Erro!", "N�o foi poss�vel carregar os links para download. Verifique sua conex�o com a internet! Caso o erro persistir contacte o departamento de TI", "error");
        });
    }

    //--------------------------------------------------------------------------------
    // FUNCAO PARA ENVIAR ANEXOS (UPLOAD)
    //--------------------------------------------------------------------------------
    function salvarAnexos() {
        const url = `painel_contratos.pl?nocache=${new Date().getTime()}`;
        const form = document.getElementById('formUploadAnexos');
        const modal = $('#modal-downloads');
        const spinnerOverlay = modal.find('.loading-spinner-overlay');

        if (!form) return;

        // Verificar se pelo menos um arquivo foi selecionado
        const inputContrato = form.querySelector('#uploadContratoAssinado');
        const inputComprovante = form.querySelector('#uploadComprovantePagamento');

        if ((!inputContrato || inputContrato.files.length === 0) && (!inputComprovante || inputComprovante.files.length === 0)) {
            Swal.fire("Atencao!", "Selecione pelo menos um arquivo para enviar.", "warning");
            return;
        }

        spinnerOverlay.css('display', 'flex');
        const formData = new FormData(form);
        formData.append('acao', 'UPLOAD_ANEXO');

        fetch(url, {
            method: 'POST',
            body: formData
        })
        .then(response => response.json())
        .then(data => {
            spinnerOverlay.hide();
            if (data.success) {
                Swal.fire({
                    title: "Sucesso!",
                    text: data.message,
                    icon: "success",
                    timer: 2000,
                    showConfirmButton: false
                }).then(() => {
                    // Recarregar o modal para mostrar os novos arquivos
                    const idContrato = document.getElementById('idContratoAnexo').value;
                    mostrarModalDownloads(idContrato);
                    // Recarregar tabela se existir
                    if ($.fn.dataTable.isDataTable('#tabelaContratos')) {
                        $('#tabelaContratos').DataTable().ajax.reload(null, false);
                    }
                });
            } else {
                Swal.fire("Erro!", data.message || "Ocorreu um erro ao enviar os arquivos.", "error");
            }
        })
        .catch(error => {
            spinnerOverlay.hide();
            Swal.fire("Erro de comunicacao!", "Nao foi possivel conectar ao servidor.", "error");
        });
    }

    //--------------------------------------------------------------------------------
    // MOSTRAR DETALHES DO CONTRATO
    //--------------------------------------------------------------------------------
    function mostrarDetalhes(idContrato) {
        const url = `painel_contratos.pl?acao=CONSULTAR_DETALHES&id=${idContrato}&nocache=${new Date().getTime()}`;
        const modal = $('#modal-detalhes');
        const spinnerOverlay = modal.find('.loading-spinner-overlay');
        const contentDiv = $('#conteudoDetalhes');

        contentDiv.empty();
        spinnerOverlay.css('display', 'flex');
        modal.modal('show');

        fetch(url)
        .then(response => {
            if (!response.ok) {
                return response.json().then(err => Promise.reject(err));
            }
            return response.text();
        })
        .then(html => {
            contentDiv.html(html);
            spinnerOverlay.hide();
        })
        .catch(error => {
            spinnerOverlay.hide();
            modal.modal('hide');
            Swal.fire("Erro!", "Nao foi possivel carregar os detalhes do contrato.", "error");
        });
    }

    //--------------------------------------------------------------------------------
    // AUTO-CALCULO E VALIDACAO: valorTotal = entradaInicial + entradaRestante + valorCaso
    //--------------------------------------------------------------------------------
    function parseMoeda(valor) {
        if (!valor) return 0;
        valor = valor.replace(/\./g, '').replace(',', '.');
        return parseFloat(valor) || 0;
    }

    function formatMoeda(valor) {
        return valor.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    }

    function calcularValorTotal() {
        const entradaInicial  = parseMoeda(document.getElementById('entradaInicial').value);
        const entradaRestante = parseMoeda(document.getElementById('entradaRestante').value);
        const valorCaso       = parseMoeda(document.getElementById('valorCaso').value);
        const soma = entradaInicial + entradaRestante + valorCaso;
        document.getElementById('valorTotal').value = formatMoeda(soma);
    }

    function validarValorTotal() {
        const valorTotal      = parseMoeda(document.getElementById('valorTotal').value);
        const entradaInicial  = parseMoeda(document.getElementById('entradaInicial').value);
        const entradaRestante = parseMoeda(document.getElementById('entradaRestante').value);
        const valorCaso       = parseMoeda(document.getElementById('valorCaso').value);
        const soma = entradaInicial + entradaRestante + valorCaso;

        if (Math.abs(valorTotal - soma) > 0.01) {
            Swal.fire({
                title: "Valor Total Incorreto!",
                html: `O <b>Valor Total</b> (R$ ${formatMoeda(valorTotal)}) deve ser igual a soma de:<br><br>` +
                      `Entrada Inicial: R$ ${formatMoeda(entradaInicial)}<br>` +
                      `+ Entrada Restante: R$ ${formatMoeda(entradaRestante)}<br>` +
                      `+ Valor Caso: R$ ${formatMoeda(valorCaso)}<br>` +
                      `<hr><b>= R$ ${formatMoeda(soma)}</b>`,
                icon: "error",
                confirmButtonText: "Corrigir"
            });
            return false;
        }
        return true;
    }

    function concluirContrato(idContrato) {
        realizarAcaoContrato('CONCLUIR_CONTRATO', idContrato, {
            title: "Tem certeza?",
            text: "O contrato ser� marcado como conclu�do. Voc� n�o poder� reverter isso!",
            icon: "warning",
            confirmButtonText: "Sim, concluir!",
            successTitle: "Conclu�do!",
            successText: "O contrato foi conclu�do com sucesso."
        });
    }

    function ativarContrato(idContrato) {
        realizarAcaoContrato('ATIVAR_CONTRATO', idContrato, {
            title: "Ativar Contrato",
            text: "Deseja realmente ativar este contrato?",
            icon: "question",
            confirmButtonText: "Sim, ativar!",
            successTitle: "Ativado!",
            successText: "O contrato foi ativado com sucesso."
        });
    }

    function inativarContrato(idContrato) {
        realizarAcaoContrato('INATIVAR_CONTRATO', idContrato, {
            title: "Desativar Contrato",
            text: "Deseja realmente desativar este contrato?",
            icon: "warning",
            confirmButtonText: "Sim, desativar!",
            successTitle: "Desativado!",
            successText: "O contrato foi desativado com sucesso."
        });
    }

    function realizarAcaoContrato(acao, idContrato, mensagens) {
		const url = `painel_contratos.pl?nocache=${new Date().getTime()}`;

        Swal.fire({
            title: mensagens.title,
            text: mensagens.text,
            icon: mensagens.icon,
            showCancelButton: true,
            confirmButtonColor: "#3085d6",
            cancelButtonColor: "#d33",
            confirmButtonText: mensagens.confirmButtonText,
            cancelButtonText: "Cancelar"
        }).then((result) => {
            if (result.isConfirmed) {
                const formData = new FormData();
				formData.append('acao', acao);
                formData.append('idContrato', idContrato);

                fetch(url, {
                    method: 'POST',
                    body: formData
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        Swal.fire(mensagens.successTitle, mensagens.successText, "success");
                        $('#tabelaContratos').DataTable().ajax.reload(null, false);
                    } else {
                        Swal.fire("Erro!", "Ocorreu um erro ao processar a solicita��o.", "error");
                    }
                })
                .catch(error => {
                    console.error('Detalhes do erro:', error);
                    Swal.fire("Erro de comunica��o!", "Ocorreu um erro na requisi��o.", "error");
                });
            }
        });
    }

    //--------------------------------------------------------------------------------
    // INICIALIZA��O E CONTROLE DO DATATABLES
    //--------------------------------------------------------------------------------
    $(document).ready(function() {
        $('#btnConsultar').on('click', function(e) {
            e.preventDefault();
            var boxConsulta = $('#boxConsulta');

            if (boxConsulta.hasClass('collapsed-box')) {
                boxConsulta.removeClass('collapsed-box');
                $('#boxConsultaIcon').removeClass('fa-plus').addClass('fa-minus');
            }
            if ($.fn.dataTable.isDataTable('#tabelaContratos')) {
                $('#tabelaContratos').DataTable().ajax.reload();
            } else {
                $('#tabelaContratos').DataTable({
                    'processing': true,
                    'serverSide': true,
                    'ajax': {
                        'url': 'painel_contratos.pl?acao=CONSULTAR_DADOS',
                        'type': 'GET',
                        'data': function(d) {
                            d.idContrato    = $('#idContratoFiltro').val();
                            d.tipoContrato  = $('#tipoContratoFiltro').val();
                            d.dataInicial   = $('#dataInicial').val();
                            d.dataFinal     = $('#dataFinal').val();
                            d.idCliente     = $('#clienteFiltro').val();
							d.statusContrato =  $('#status').val();
                        },
                        'error': function (xhr, error, thrown) {
                            console.error("Erro do servidor:", xhr.status, xhr.responseJSON || xhr.responseText);
                            Swal.fire({
                                title: 'Erro ao Carregar Dados',
                                text: 'N�o foi poss�vel carregar os dados da tabela. Verifique sua conex�o com a internet! Caso o erro persistir contacte o departamento de TI',
                                icon: 'error',
                                confirmButtonText: 'Fechar'
                            }).then(() => {
                                window.location.href = "painel_contratos.pl";
                            });
                        }
                    },
                    'paging': true,
                    'lengthChange': false,
                    'searching': false,
                    'ordering': false,
                    'info': false,
                    'autoWidth': false,
                    'pageLength': 30,
                    'language': {
                        'decimal': ',',
                        'thousands': '.',
                        'processing': 'Processando...',
                        'zeroRecords': 'Nenhum resultado encontrado',
                        'search': 'Buscar:',
                        'paginate': {
                            'first': 'Primeiro',
                            'last': '�ltimo',
                            'next': 'Pr�ximo',
                            'previous': 'Anterior'
                        }
                    },
                    responsive: true,
                    'dom':  "<'row'<'col-sm-12'tr>>" +
                          "<'row'<'col-sm-12'p>>",
                    'columnDefs': [
                        {
                            "targets": "_all",
                            "className": "text-center"
                        },
                        {
                            "targets": 1, // Coluna Status
                            "orderable": false,
                            "render": function(data, type, row) {
                                const status = data;
                                const statusMap = {
                                    1: { 'classe': 'bg-green', 'texto': 'Ativo' },
                                    8: { 'classe': 'bg-blue', 'texto': 'Conclu�do' },
                                    9: { 'classe': 'bg-red', 'texto': 'Inativo' }
                                };
                                const statusInfo = statusMap[status] || { 'classe': 'bg-gray', 'texto': 'N/D' };
                                return `<span class="badge ${statusInfo.classe}">${statusInfo.texto}</span>`;
                            }
                        },
                        {
                            "targets": 6, // Dt. Contrato Assinado
                            "render": function(data, type, row) {
                                return row[8] || '';
                            }
                        },
                        {
                            "targets": 7, // Dt. Conclus�o
                            "render": function(data, type, row) {
                                return row[9] || '';
                            }
                        },
                        {
                            "targets": 8, // A��es
                            "orderable": false,
                            "render": function(data, type, row) {
                                const idContrato = row[0];
                                const status = row[1];
                                let botoes = '';

                                botoes += `<button type='button' class='btn btn-xs btn-primary' title='Mostrar Detalhes' onClick='mostrarDetalhes(${idContrato})'><i class="glyphicon glyphicon-zoom-in"></i></button> `;

                                botoes += `<button type='button' class='btn btn-xs btn-info' title='Ver Downloads' onClick='mostrarModalDownloads(${idContrato})'><i class="fa fa-download"></i></button> `;

                                // Editar (somente se nao houver contrato assinado anexado)
                                const anexoContratoAssinado = row[6];
                                if(Direitos1 && !anexoContratoAssinado){
                                    botoes += `<button type='button' class='btn btn-xs bg-yellow' title='Editar Contrato' onClick='editarContrato(${idContrato})'><span class="glyphicon glyphicon-pencil"></span></button> `;
                                }

                                // Bot�o Concluir (se status for 1 - Ativo)
                                if (Direitos2 && status == 1) {
                                    botoes += `<button type='button' class='btn btn-xs' title='Concluir Contrato' style='background-color: #6f42c1; color: white;' onClick='concluirContrato(${idContrato})'><i class='glyphicon glyphicon-ok'></i></button> `;
                                }

                                // Ativar/Inativar
                                if(Direitos1){
                                    if (status == 1 || status == 8) {
                                        botoes += `<button type='button' class='btn btn-danger btn-xs' title='Desativar Contrato?' onClick='inativarContrato(${idContrato})'><span class='glyphicon glyphicon-remove'></span></button>`;
                                    } else {
                                        botoes += `<button type='button' class='btn btn-success btn-xs' title='Ativar Contrato?' onClick='ativarContrato(${idContrato})'><span class='glyphicon glyphicon-ok'></span></button>`;
                                    }
                                }

                                return botoes;
                            }
                        }
                    ]
                });
            }
        });
    });
</script>
HTML

print $footer;