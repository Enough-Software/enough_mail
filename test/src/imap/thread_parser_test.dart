import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/imap/all_parsers.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/private/imap/imap_response_line.dart';
import 'package:test/test.dart';
// cSpell:disable

void main() {
  test('Thread nested', () {
    const responseText = 'THREAD (2)(3 6 (4 23)(44 7 96))';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = ThreadParser(isUidSequence: false);
    final response = Response<SequenceNode>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    expect(parser.result, isNotNull);
    //print(parser.result);
    expect(parser.result.isNotEmpty, isTrue);
    expect(parser.result.length, 2);
    expect(parser.result[0].hasId, false);
    expect(parser.result[0].length, 1);
    expect(parser.result[0][0].id, 2);
    expect(parser.result[1].hasId, false);
    expect(parser.result[1].length, 4);
    expect(parser.result[1][0].id, 3);
    expect(parser.result[1][1].id, 6);
    expect(parser.result[1][2].hasId, false);
    expect(parser.result[1][2].length, 2);
    expect(parser.result[1][2][0].id, 4);
    expect(parser.result[1][2][1].id, 23);
    expect(parser.result[1][3].hasId, false);
    expect(parser.result[1][3].length, 3);
    expect(parser.result[1][3][0].id, 44);
    expect(parser.result[1][3][1].id, 7);
    expect(parser.result[1][3][2].id, 96);
    final flattened = parser.result.flatten();
    //print('flattened: $flattened');
    expect(flattened, isNotNull);
    expect(flattened.length, 2);
    expect(flattened[0].length, 1);
    expect(flattened[0][0].id, 2);
    expect(flattened[1].length, 7);
    expect(flattened[1][0].id, 3);
    expect(flattened[1][6].id, 96);

    final sequence1 = parser.result.toMessageSequence();
    final sequence2 = flattened.toMessageSequence();
    expect(sequence1, isNotNull);
    expect(sequence1.isNotEmpty, isTrue);
    expect(sequence1.toList(), [2, 3, 6, 4, 23, 44, 7, 96]);
    expect(sequence2.toList(), sequence1.toList());

    expect(
        parser.result
            .toMessageSequence(mode: SequenceNodeSelectionMode.lastLeaf)
            .toList(),
        [2, 96]);
    expect(
        flattened
            .toMessageSequence(mode: SequenceNodeSelectionMode.lastLeaf)
            .toList(),
        [2, 96]);
    expect(
        parser.result
            .toMessageSequence(mode: SequenceNodeSelectionMode.firstLeaf)
            .toList(),
        [2, 3]);
    expect(
        flattened
            .toMessageSequence(mode: SequenceNodeSelectionMode.firstLeaf)
            .toList(),
        [2, 3]);
  });

  test('simple real world', () {
    const responseText = 'THREAD (62916)(62917 (63138)(63373))';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = ThreadParser(isUidSequence: false);
    final response = Response<SequenceNode>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    expect(parser.result, isNotNull);
    expect(parser.result.isNotEmpty, isTrue);
    expect(parser.result.length, 2);
    // print(parser.result);
    expect(parser.result[0][0].id, 62916);
    expect(parser.result[1][0].id, 62917);
    // print(parser.result[1]);
    expect(parser.result[1].length, 3);
    expect(parser.result[1][1][0].id, 63138);
    expect(parser.result[1][2][0].id, 63373);

    final flattened = parser.result.flatten();
    expect(flattened, isNotNull);
    expect(flattened.isNotEmpty, isTrue);
    expect(flattened.length, 2);
    expect(flattened[0].length, 1);
    expect(flattened[0][0].id, 62916);
    expect(flattened[1].length, 3);
    expect(flattened[1][0].id, 62917);
    expect(flattened[1][1].id, 63138);
    expect(flattened[1][2].id, 63373);
  });
  test('full real world', () {
    const responseText =
        '''THREAD (62916)(62917 (63138)(63373))(62918)(62919)(62920)(62921)(62922 62923)(62924 62925)(62926 62990)(62927 (62935)(62938)(62941)(62942)(62943)(62945)(62963)(62973)(62974)(63090))(62928 62937)(62929)(62930)(62931)(62932)(62933 62934)(62936)(62939)(62940)(62944 (62946)(62948)(62951)(62954))(62947)(62949)(62950)(62952)(62953 (63139)(63330))(62955)(62956)(62957)(62958)(62959)(62960)(62961)(62962)(62964 62965)(62966 62967)(62968)(62969 62972)(62970 62983)(62971)(62975)(62976 63132)(62977)(62978)(62979)(62980)(62981)(62982)(62985)(62984)(62986)(62987)(62988)(62989)(62991)(62992)(62993 (63222)(63432))(62994)(62995)(62996 62997)(62998)(62999)(63000 63001)(63002)(63003)(63004 63024)(63005)(63006)(63007)(63008)(63009)(63010)(63011)(63012)(63013)(63014 63121)(63015)(63016)(63017)(63018)(63019)(63020)(63021)(63022)(63023)(63025)(63026)(63027)(63028)(63029)(63030 (63031)(63033)(63172))(63032)(63034)(63035)(63036)(63037)(63038)(63039)(63040)(63041 63042)(63043 (63095)(63137)(63207)(63276)(63318)(63372)(63420)(63471)(63536))(63044)(63045)(63046)(63047)(63048)(63049 (63052)(63056))(63050)(63051)(63053)(63054)(63055)(63057 (63059)(63063)(63067)(63068)(63091)(63186))(63058 63272)(63060)(63061)(63062 63064)(63065)(63066)(63069 63283)(63070)(63071)(63072 63079)(63073)(63074)(63075)(63076)(63077)(63078)(63080)(63081)(63082)(63083 (63086)(63093)(63094)(63097))(63084)(63085)(63087)(63088)(63089)(63092)(63096)(63098)(63099 63100)(63101)(63102)(63103)(63104)(63105)(63106)(63107 (63109)(63111)(63113))(63108)(63110)(63112)(63114 (63120)(63295))(63115)(63116)(63117 63118)(63119)(63122 (63123)(63124))(63125)(63126)(63127 (63208)(63211)(63290)(63428)(63430))(63128)(63129)(63130)(63131)(63133)(63134)(63135)(63136 (63163)(63557)(63574))(63140 (63141)(63149)(63150))(63142)(63143)(63144 (63308)(63398))(63145)(63146)(63147)(63148 (63152)(63154)(63155))(63151)(63153)(63156)(63157)(63158)(63159)(63160)(63161)(63162)(63164)(63165)(63166 (63167)(63168)(63177)(63178)(63245)(63252))(63169)(63170)(63171 (63173)(63176)(63189)(63190)(63192)(63195)(63248))(63174 63175)(63179)(63180)(63181)(63182)(63183)(63184 (63187)(63188)(63194)(63219)(63236)(63240)(63241)(63275))(63185)(63191 63209)(63193)(63196)(63197)(63198)(63199)(63200)(63201)(63202)(63203)(63204)(63205)(63206)(63210)(63212)(63213)(63214 63377)(63215)(63216)(63217)(63218)(63220)(63221)(63223 (63232)(63233))(63224)(63225)(63226)(63227)(63228)(63229)(63230)(63231)(63234)(63235)(63237)(63238 (63239)(63242)(63259))(63243)(63244)(63246 63247)(63249)(63250)(63251)(63253)(63254)(63255)(63256 63262)(63257)(63258)(63260)(63261 (63263)(63268)(63269)(63270)(63291)(63298))(63264)(63265)(63266)(63267)(63271)(63273 (63274)(63285)(63286)(63287)(63288))(63277)(63278)(63279)(63280)(63281)(63282)(63284)(63289)(63292)(63293)(63294)(63296)(63297 63390)(63299)(63300)(63302)(63301)(63303)(63304)(63305)(63306)(63307)(63309)(63310)(63311)(63312)(63313)(63314)(63315)(63316)(63317)(63319 (63320)(63321)(63326))(63322)(63323 63324)(63325 63335)(63327)(63328)(63329)(63331)(63332)(63333)(63334)(63336 (63361)(63371))(63337)(63338)(63339)(63340)(63341 (63343)(63344)(63345)(63347)(63348)(63350)(63374))(63342)(63346)(63355)(63349)(63351)(63352)(63353)(63354)(63356)(63357)(63362 (63383)(63499))(63358)(63359)(63360)(63363)(63364)(63365)(63366 (63368)(63369))(63367)(63370)(63375)(63376)(63378 (63382)(63387)(63389)(63395))(63379)(63380)(63381)(63384 (63385)(63393)(63429)(63451))(63386)(63388)(63391)(63392)(63394)(63396)(63397)(63399 63400)(63401)(63402)(63403)(63404)(63405)(63406)(63407 (63408)(63416)(63418)(63435))(63409 63414)(63410 (63411)(63412))(63413)(63415)(63417)(63419)(63421)(63422)(63423)(63424)(63425)(63426)(63427)(63431)(63433)(63434)(63436)(63437)(63438)(63439)(63440 63441)(63442)(63443)(63444 63447)(63445)(63446)(63448)(63449)(63450)(63452)(63453 (63491)(63515)(63518)(63523))(63454)(63455)(63456 (63457)(63458)(63475)(63479)(63480)(63481)(63497))(63459)(63460)(63461)(63462)(63463 (63464)(63465))(63466)(63467)(63468 (63469)(63472))(63470)(63473)(63474)(63476)(63477)(63478)(63482)(63483)(63484 63485)(63486)(63487)(63488)(63489 63498)(63490)(63492)(63493)(63494)(63495)(63496)(63500)(63501)(63502)(63503)(63504)(63505)(63506)(63507)(63508)(63509)(63510)(63511)(63512)(63513)(63514)(63516)(63517)(63519 (63520)(63521)(63522))(63524)(63525 (63526)(63527))(63528)(63529)(63530)(63531)(63532 63533)(63534)(63535)(63537)(63543)(63542)(63539)(63538 63540)(63541)(63544 63556)(63545 (63546)(63550))(63547)(63548 63578)(63549 (63554)(63555))(63551)(63552 63581)(63553)(63558 (63559)(63560))(63561 63562)(63563)(63564)(63565)(63566)(63567)(63568 (63569)(63570)(63571)(63572)(63575))(63573)(63576)(63577)(63579)(63580)(63582)(63583)''';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = ThreadParser(isUidSequence: false);
    final response = Response<SequenceNode>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    expect(parser.result, isNotNull);
    expect(parser.result.isNotEmpty, isTrue);
    expect(parser.result[0][0].id, 62916);
    expect(parser.result[1][0].id, 62917);

    expect(parser.result[parser.result.length - 1][0].id, 63583);
    final flattened = parser.result.flatten();
    expect(flattened, isNotNull);
    expect(flattened.isNotEmpty, isTrue);
    expect(flattened[0][0].id, 62916);
    expect(flattened[flattened.length - 1][0].id, 63583);
  });
}
