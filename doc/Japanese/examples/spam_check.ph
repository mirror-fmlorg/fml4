#
# $FML$
#
# ����� perl script �Ǥ���
# �Ȥ����� virus_check.ph �ʤɤ�Ʊ�ͤǤ���
#
# ���̤ͣ˰쵤��Ŭ�Ѥ��뤿��ˤ�
#    /var/spool/ml/etc/fml/site_force.ph
# ���դ��ä��ƻ��Ѥ��ޤ�(path�Ϥ�ߤ����Ƥ���������)��
#
# �ե��륿�������
#    http://www.fml.org/fml/Japanese/filter/index.html
#
# ���塼�ȥꥢ��
#    http://www.fml.org/fml/Japanese/tutorial.html
#

#
# 1. SPAM �ˤĤ��� 
#
#    �ե��륿�λ����ˤ��礭��ʬ���ƣ��Ȥ��ꤢ��ޤ���
#    ���������פ��Ƥ������᡼��Υ���ƥ�Ĥ�Ƚ�Ǥ��뤫���Ǥ���


#
# Q: �᡼������Ƥ˱������Ƥ�
#

# http://www.meti.go.jp/kohosys/press/0002285/
# �� (�����Х���)��ñ���Ϥ�����ե졼���� Subect: �ˤĤ����
# SPAM �Ϲ�ˡ�������ΤǤ��礦���� (�ɤ�����ˡΧ�����)
# ���������櫓�ǡ��Ƥ��Ƥߤޤ��礦��
# �Ƥ�����ñ��� | �Ƕ��ڤäƷҤ��Ʋ�������
&DEFINE_FIELD_PAT_TO_REJECT('Subject', '�����ѥࡪ|������');

# �ɡ��ʤ�Ǥ⡪ �ɤ��Ƥ����Ƥ��᤮���⤷��ޤ���
# �������������ɤ��ȸ������ϡ��ʲ��Υ�����( # )�򳰤��Ƹ��Ʋ�������
# &DEFINE_FIELD_PAT_TO_REJECT('Subject', '��\S+��');



#
# Q: �������˱������Ƥ�
#

# ���������Ƥ����ϡ�RBL �����Ѥ���Τ����̤Ǥ�����
# �᡼�륵���Ф��Ƥ����Ȥߤ�����Τǡ���������Ѥ��뤳�Ȥ�¿���Ǥ���
#     A1. �ޤ��� rbl �ǥ������� ���եڡ������ߤĤ���ޤä�:)
#     A2. postfix �Ǥ� maps_rbl_domains �Ȥ����ѿ��򻲾Ȥ��Ʋ�������
#     A3. qmail �Ǥ� rblsmtpd �ʤɤ������ؤ���ʤɤμ��ʤ�����ޤ���
#         �ޤ��� www.qmail.org �����󥯤򤿤ɤäƲ�������
#     A4. sendmail �� www.sendmail.org ���餿�ɤ����͡�


# ��ե����
#    SPAM �Υꥹ��
#    http://libertas.wirehub.net/spamlist.txt 
#

1;